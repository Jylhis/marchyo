package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"regexp"
	"slices"
	"strings"
	"time"
)

const (
	longTimeout  = 120 * time.Second
	shortTimeout = 30 * time.Second
	defaultLines = 200
)

var ansiRe = regexp.MustCompile(`\x1b\[[0-9;?]*[ -/]*[@-~]`)

type content struct {
	Type     string `json:"type"`
	Text     string `json:"text,omitempty"`
	Data     string `json:"data,omitempty"`
	MimeType string `json:"mimeType,omitempty"`
}

type toolResult struct {
	Content []content `json:"content"`
	IsError bool      `json:"isError,omitempty"`
}

type tool struct {
	name, description string
	schema            map[string]any
	timeout           time.Duration
	handler           handlerFunc
}

type server struct {
	run    Runner
	tmpDir string
	tools  map[string]tool
}

func textResult(s string) toolResult {
	return toolResult{Content: []content{{Type: "text", Text: s}}}
}

func errorResult(s string) toolResult {
	r := textResult(s)
	r.IsError = true
	return r
}

func stripANSI(s string) string { return ansiRe.ReplaceAllString(s, "") }

func newServer(run Runner, tmpDir string) *server {
	s := &server{run: run, tmpDir: tmpDir, tools: map[string]tool{}}
	for _, t := range s.definitions() {
		s.tools[t.name] = t
	}
	return s
}

func (s *server) toolList() []map[string]any {
	names := make([]string, 0, len(s.tools))
	for n := range s.tools {
		names = append(names, n)
	}
	slices.Sort(names)
	list := make([]map[string]any, 0, len(names))
	for _, n := range names {
		t := s.tools[n]
		list = append(list, map[string]any{
			"name": t.name, "description": t.description, "inputSchema": t.schema,
		})
	}
	return list
}

// exec runs a script and turns a failure into an error carrying its stderr text.
func (s *server) exec(ctx context.Context, script string, args ...string) (string, error) {
	stdout, stderr, err := s.run(ctx, script, args...)
	if err == nil {
		return stdout, nil
	}
	if errors.Is(err, context.DeadlineExceeded) {
		return "", fmt.Errorf("%s timed out", script)
	}
	msg := strings.TrimSpace(stripANSI(stderr))
	if msg == "" {
		msg = strings.TrimSpace(stripANSI(stdout))
	}
	return "", fmt.Errorf("%s failed (%v): %s", script, err, msg)
}

func decode(raw json.RawMessage, v any) error {
	if len(raw) == 0 {
		raw = json.RawMessage("{}")
	}
	if err := json.Unmarshal(raw, v); err != nil {
		return fmt.Errorf("invalid arguments: %w", err)
	}
	return nil
}

func requireField(name, v string) error {
	if strings.TrimSpace(v) == "" {
		return fmt.Errorf("%s must not be empty", name)
	}
	if strings.HasPrefix(strings.TrimSpace(v), "-") {
		return fmt.Errorf("%s must not start with '-'", name)
	}
	return nil
}

type handlerFunc = func(context.Context, json.RawMessage) (toolResult, error)

func (s *server) simple(script string, args ...string) handlerFunc {
	return func(ctx context.Context, _ json.RawMessage) (toolResult, error) {
		out, err := s.exec(ctx, script, args...)
		if err != nil {
			return toolResult{}, err
		}
		return textResult(strings.TrimSpace(stripANSI(out))), nil
	}
}

func (s *server) up(ctx context.Context, raw json.RawMessage) (toolResult, error) {
	var a struct {
		Fixture string `json:"fixture"`
		Real    bool   `json:"real"`
		Window  bool   `json:"window"`
	}
	if err := decode(raw, &a); err != nil {
		return toolResult{}, err
	}
	args := []string{"up"}
	if a.Window {
		args = append(args, "--window")
	}
	if a.Real {
		args = append(args, "--real")
	}
	if a.Fixture != "" {
		if err := requireField("fixture", a.Fixture); err != nil {
			return toolResult{}, err
		}
		args = append(args, "--fixture", a.Fixture)
	}
	out, err := s.exec(ctx, "sandbox", args...)
	if err != nil {
		return toolResult{}, err
	}
	return textResult(strings.TrimSpace(stripANSI(out)) + "\nsandbox up"), nil
}

func (s *server) status(ctx context.Context, _ json.RawMessage) (toolResult, error) {
	stdout, stderr, err := s.run(ctx, "sandbox", "status")
	text := strings.TrimSpace(stripANSI(stdout + stderr))
	if ee, ok := errors.AsType[*exitError](err); ok && ee.Code == 1 {
		return textResult(strings.TrimSpace("stopped\n" + text)), nil
	}
	if err != nil {
		return toolResult{}, fmt.Errorf("status failed (%v): %s", err, text)
	}
	return textResult(strings.TrimSpace("running\n" + text)), nil
}

func (s *server) ipcCall(ctx context.Context, raw json.RawMessage) (toolResult, error) {
	var a struct {
		Target   string   `json:"target"`
		Function string   `json:"function"`
		Args     []string `json:"args"`
	}
	if err := decode(raw, &a); err != nil {
		return toolResult{}, err
	}
	err := errors.Join(requireField("target", a.Target), requireField("function", a.Function))
	if err != nil {
		return toolResult{}, err
	}
	argv := append([]string{"ipc", "call", a.Target, a.Function}, a.Args...)
	out, err := s.exec(ctx, "sandbox", argv...)
	if err != nil {
		return toolResult{}, err
	}
	return textResult(strings.TrimSpace(stripANSI(out))), nil
}

func (s *server) logs(ctx context.Context, raw json.RawMessage) (toolResult, error) {
	var a struct {
		Lines int `json:"lines"`
	}
	if err := decode(raw, &a); err != nil {
		return toolResult{}, err
	}
	if a.Lines < 0 {
		return toolResult{}, errors.New("lines must not be negative")
	}
	if a.Lines == 0 {
		a.Lines = defaultLines
	}
	out, err := s.exec(ctx, "sandbox", "log")
	if err != nil {
		return toolResult{}, err
	}
	lines := strings.Split(strings.TrimRight(stripANSI(out), "\n"), "\n")
	if len(lines) > a.Lines {
		lines = lines[len(lines)-a.Lines:]
	}
	return textResult(strings.Join(lines, "\n")), nil
}

type shotArgs struct {
	Surface string   `json:"surface"`
	State   []string `json:"state"`
	IPC     []string `json:"ipc"`
	Grab    bool     `json:"grab"`
	Fixture string   `json:"fixture"`
}

func (a shotArgs) argv(out string) []string {
	argv := []string{a.Surface, "--out", out}
	for _, st := range a.State {
		argv = append(argv, "--state", st)
	}
	for _, c := range a.IPC {
		argv = append(argv, "--ipc", c)
	}
	if a.Grab {
		argv = append(argv, "--grab")
	}
	if a.Fixture != "" {
		argv = append(argv, "--fixture", a.Fixture)
	}
	return argv
}

func (s *server) screenshot(ctx context.Context, raw json.RawMessage) (toolResult, error) {
	var a shotArgs
	if err := decode(raw, &a); err != nil {
		return toolResult{}, err
	}
	if err := requireField("surface", a.Surface); err != nil {
		return toolResult{}, err
	}
	out, err := s.newShotPath()
	if err != nil {
		return toolResult{}, err
	}
	_, stderr, err := s.run(ctx, "shot", a.argv(out)...)
	if err != nil {
		msg := strings.TrimSpace(stripANSI(stderr))
		return toolResult{}, fmt.Errorf("shot failed (%v): %s", err, msg)
	}
	return shotResult(out, qmlWarnings(stripANSI(stderr)))
}

// qmlWarnings keeps the shell's WARN/ERROR lines from shot's stderr, dropping
// the devenv progress lines around them.
func qmlWarnings(stderr string) string {
	var kept []string
	for line := range strings.Lines(stderr) {
		if strings.Contains(line, "WARN") || strings.Contains(line, "ERROR") {
			kept = append(kept, strings.TrimRight(line, "\n"))
		}
	}
	return strings.Join(kept, "\n")
}

func (s *server) newShotPath() (string, error) {
	if err := os.MkdirAll(s.tmpDir, 0o755); err != nil {
		return "", err
	}
	f, err := os.CreateTemp(s.tmpDir, "shot-*.png")
	if err != nil {
		return "", err
	}
	return f.Name(), f.Close()
}

func shotResult(path, warnings string) (toolResult, error) {
	png, err := os.ReadFile(path)
	if err != nil || len(png) == 0 {
		return toolResult{}, fmt.Errorf("shot produced no image at %s", path)
	}
	text := "screenshot: " + path
	if w := strings.TrimSpace(warnings); w != "" {
		text += "\nwarnings:\n" + w
	}
	return toolResult{Content: []content{
		{Type: "image", Data: base64.StdEncoding.EncodeToString(png), MimeType: "image/png"},
		{Type: "text", Text: text},
	}}, nil
}
