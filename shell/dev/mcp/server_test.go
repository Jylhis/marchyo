package main

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"image"
	"image/png"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

type call struct {
	script string
	args   []string
}

type fake struct {
	calls  []call
	stdout string
	stderr string
	err    error
	onRun  func(args []string)
}

func (f *fake) run(_ context.Context, script string, args ...string) (string, string, error) {
	f.calls = append(f.calls, call{script, args})
	if f.onRun != nil {
		f.onRun(args)
	}
	return f.stdout, f.stderr, f.err
}

// tinyPNG is a 1x1 PNG.
var tinyPNG = func() []byte {
	var b bytes.Buffer
	_ = png.Encode(&b, image.NewGray(image.Rect(0, 0, 1, 1)))
	return b.Bytes()
}()

func exchange(t *testing.T, s *server, lines ...string) []map[string]any {
	t.Helper()
	var out bytes.Buffer
	in := strings.NewReader(strings.Join(lines, "\n") + "\n")
	if err := serve(t.Context(), s, in, &out); err != nil {
		t.Fatal(err)
	}
	var resps []map[string]any
	for line := range strings.SplitSeq(strings.TrimSpace(out.String()), "\n") {
		if line == "" {
			continue
		}
		var m map[string]any
		if err := json.Unmarshal([]byte(line), &m); err != nil {
			t.Fatalf("bad output line %q: %v", line, err)
		}
		resps = append(resps, m)
	}
	return resps
}

func TestProtocolRoundTrip(t *testing.T) {
	f := &fake{stdout: "shell\n  reload()\n"}
	s := newServer(f.run, t.TempDir())
	resps := exchange(t, s,
		`{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26"}}`,
		`{"jsonrpc":"2.0","method":"notifications/initialized"}`,
		`{"jsonrpc":"2.0","id":2,"method":"ping"}`,
		`{"jsonrpc":"2.0","id":3,"method":"tools/list"}`,
		`{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"ipc_show"}}`,
		`{"jsonrpc":"2.0","id":5,"method":"nope"}`,
	)
	if len(resps) != 5 {
		t.Fatalf("want 5 responses (no reply to the notification), got %d", len(resps))
	}
	init := resps[0]["result"].(map[string]any)
	if init["protocolVersion"] != "2025-03-26" {
		t.Errorf("protocolVersion = %v", init["protocolVersion"])
	}
	tools := resps[2]["result"].(map[string]any)["tools"].([]any)
	if len(tools) != 8 {
		t.Errorf("want 8 tools, got %d", len(tools))
	}
	res := resps[3]["result"].(map[string]any)
	if res["isError"] == true || !strings.Contains(res["content"].([]any)[0].(map[string]any)["text"].(string), "reload()") {
		t.Errorf("unexpected tool result: %v", res)
	}
	want := call{"sandbox", []string{"ipc", "show"}}
	if len(f.calls) != 1 || f.calls[0].script != want.script || !slices.Equal(f.calls[0].args, want.args) {
		t.Errorf("calls = %v", f.calls)
	}
	if code := resps[4]["error"].(map[string]any)["code"]; code != float64(-32601) {
		t.Errorf("unknown method code = %v", code)
	}
}

func TestInitializeFallbackVersion(t *testing.T) {
	s := newServer((&fake{}).run, t.TempDir())
	r := exchange(t, s, `{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"1999"}}`)
	if v := r[0]["result"].(map[string]any)["protocolVersion"]; v != "2025-06-18" {
		t.Errorf("protocolVersion = %v", v)
	}
}

func TestScreenshotContent(t *testing.T) {
	dir := t.TempDir()
	f := &fake{stderr: "\x1b[33mWARN foo.qml:3 bad\x1b[0m\n"}
	f.onRun = func(args []string) {
		i := slices.Index(args, "--out")
		if err := os.WriteFile(args[i+1], tinyPNG, 0o644); err != nil {
			t.Error(err)
		}
	}
	s := newServer(f.run, dir)
	raw := json.RawMessage(`{"surface":"launcher:apps","state":["query=fire"],` +
		`"ipc":["shell osdShow Volume 40 true"],"grab":true,"fixture":"default"}`)
	res, err := s.screenshot(t.Context(), raw)
	if err != nil {
		t.Fatal(err)
	}
	if len(res.Content) != 2 || res.Content[0].Type != "image" || res.Content[0].MimeType != "image/png" {
		t.Fatalf("content = %+v", res.Content)
	}
	got, _ := base64.StdEncoding.DecodeString(res.Content[0].Data)
	if !bytes.Equal(got, tinyPNG) {
		t.Error("image data differs")
	}
	txt := res.Content[1].Text
	if !strings.Contains(txt, dir) || !strings.Contains(txt, "WARN foo.qml:3 bad") || strings.Contains(txt, "\x1b") {
		t.Errorf("text = %q", txt)
	}
	args := f.calls[0].args
	for _, w := range []string{"launcher:apps", "--state", "query=fire", "--ipc", "--grab", "--fixture"} {
		if !slices.Contains(args, w) {
			t.Errorf("argv %v lacks %q", args, w)
		}
	}
	if !slices.Contains(args, "shell osdShow Volume 40 true") {
		t.Errorf("ipc call must be one argv entry: %v", args)
	}
}

func TestScreenshotNoImage(t *testing.T) {
	s := newServer((&fake{}).run, t.TempDir())
	if _, err := s.screenshot(t.Context(), json.RawMessage(`{"surface":"screen"}`)); err == nil {
		t.Error("want error when shot writes nothing")
	}
}

func TestStripANSI(t *testing.T) {
	if got := stripANSI("\x1b[1;31mred\x1b[0m plain \x1b[2K"); got != "red plain " {
		t.Errorf("got %q", got)
	}
}

func TestLogsTailAndStrip(t *testing.T) {
	f := &fake{stdout: "\x1b[31ma\x1b[0m\nb\nc\nd\n"}
	s := newServer(f.run, t.TempDir())
	res, err := s.logs(t.Context(), json.RawMessage(`{"lines":2}`))
	if err != nil {
		t.Fatal(err)
	}
	if res.Content[0].Text != "c\nd" {
		t.Errorf("got %q", res.Content[0].Text)
	}
}

func TestStatusStopped(t *testing.T) {
	f := &fake{err: &exitError{Code: 1}}
	s := newServer(f.run, t.TempDir())
	res, err := s.status(t.Context(), nil)
	if err != nil || !strings.HasPrefix(res.Content[0].Text, "stopped") {
		t.Errorf("res=%+v err=%v", res, err)
	}
}

func TestValidation(t *testing.T) {
	f := &fake{}
	s := newServer(f.run, filepath.Join(t.TempDir(), "x"))
	cases := map[string]string{
		"screenshot": `{"surface":"  "}`,
		"ipc_call":   `{"target":"shell","function":""}`,
		"sandbox_up": `{"fixture":"--evil"}`,
	}
	for name, args := range cases {
		res, err := s.callTool(t.Context(), json.RawMessage(`{"name":"`+name+`","arguments":`+args+`}`))
		if err != nil {
			t.Fatalf("%s: protocol error %v", name, err)
		}
		if !res.(toolResult).IsError {
			t.Errorf("%s: want isError", name)
		}
	}
	if len(f.calls) != 0 {
		t.Errorf("runner must not run on invalid input: %v", f.calls)
	}
}

func TestToolFailureIsResult(t *testing.T) {
	f := &fake{stderr: "boom", err: &exitError{Code: 2}}
	s := newServer(f.run, t.TempDir())
	res, rerr := s.callTool(t.Context(), json.RawMessage(`{"name":"reload"}`))
	if rerr != nil {
		t.Fatal(rerr)
	}
	tr := res.(toolResult)
	if !tr.IsError || !strings.Contains(tr.Content[0].Text, "boom") {
		t.Errorf("got %+v", tr)
	}
}

func TestQMLWarningsDropsDevenvLines(t *testing.T) {
	in := "• Running devenv:enterShell\ndevenv ready\n  WARN qml: x\n ERROR y\n"
	if got, want := qmlWarnings(in), "  WARN qml: x\n ERROR y"; got != want {
		t.Fatalf("qmlWarnings = %q, want %q", got, want)
	}
}
