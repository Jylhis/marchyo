package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"slices"
	"sync"
)

const (
	defaultProtocol = "2025-06-18"
	errMethod       = -32601
	errParams       = -32602
	errParse        = -32700
	errInvalid      = -32600
)

var supportedProtocols = []string{"2025-06-18", "2025-03-26", "2024-11-05"}

type request struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
}

type rpcError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

type response struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id"`
	Result  any             `json:"result,omitempty"`
	Error   *rpcError       `json:"error,omitempty"`
}

type transport struct {
	mu  sync.Mutex
	out io.Writer
}

func (t *transport) send(r response) {
	r.JSONRPC = "2.0"
	b, err := json.Marshal(r)
	if err != nil {
		log.Printf("marshal response: %v", err)
		return
	}
	t.mu.Lock()
	defer t.mu.Unlock()
	if _, err := t.out.Write(append(b, '\n')); err != nil {
		log.Printf("write response: %v", err)
	}
}

func serve(ctx context.Context, s *server, in io.Reader, out io.Writer) error {
	tr := &transport{out: out}
	sc := bufio.NewScanner(in)
	sc.Buffer(make([]byte, 0, 64*1024), 16*1024*1024)
	for sc.Scan() {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		line := sc.Bytes()
		if len(line) == 0 {
			continue
		}
		if resp, ok := s.handleLine(ctx, line); ok {
			tr.send(resp)
		}
	}
	return sc.Err()
}

func (s *server) handleLine(ctx context.Context, line []byte) (response, bool) {
	var req request
	if err := json.Unmarshal(line, &req); err != nil {
		return fail(nil, errParse, "parse error"), true
	}
	if req.Method == "" {
		return fail(req.ID, errInvalid, "invalid request"), len(req.ID) > 0
	}
	isNotification := len(req.ID) == 0
	result, rerr := s.dispatch(ctx, req)
	if isNotification {
		return response{}, false
	}
	if rerr != nil {
		return response{ID: req.ID, Error: rerr}, true
	}
	return response{ID: req.ID, Result: result}, true
}

func fail(id json.RawMessage, code int, msg string) response {
	if id == nil {
		id = json.RawMessage("null")
	}
	return response{ID: id, Error: &rpcError{Code: code, Message: msg}}
}

func (s *server) dispatch(ctx context.Context, req request) (any, *rpcError) {
	switch req.Method {
	case "initialize":
		return s.initialize(req.Params), nil
	case "notifications/initialized", "notifications/cancelled":
		return nil, nil
	case "ping":
		return struct{}{}, nil
	case "tools/list":
		return map[string]any{"tools": s.toolList()}, nil
	case "tools/call":
		return s.callTool(ctx, req.Params)
	}
	return nil, &rpcError{Code: errMethod, Message: fmt.Sprintf("method not found: %s", req.Method)}
}

func (s *server) initialize(params json.RawMessage) any {
	var p struct {
		ProtocolVersion string `json:"protocolVersion"`
	}
	_ = json.Unmarshal(params, &p)
	version := defaultProtocol
	if slices.Contains(supportedProtocols, p.ProtocolVersion) {
		version = p.ProtocolVersion
	}
	return map[string]any{
		"protocolVersion": version,
		"capabilities":    map[string]any{"tools": map[string]any{}},
		"serverInfo":      map[string]any{"name": "marchyo-shell", "version": "0.1.0"},
	}
}

func (s *server) callTool(ctx context.Context, params json.RawMessage) (any, *rpcError) {
	var p struct {
		Name      string          `json:"name"`
		Arguments json.RawMessage `json:"arguments"`
	}
	if err := json.Unmarshal(params, &p); err != nil {
		return nil, &rpcError{Code: errParams, Message: "invalid params"}
	}
	t, ok := s.tools[p.Name]
	if !ok {
		return nil, &rpcError{Code: errParams, Message: "unknown tool: " + p.Name}
	}
	ctx, cancel := context.WithTimeout(ctx, t.timeout)
	defer cancel()
	res, err := t.handler(ctx, p.Arguments)
	if err != nil {
		return errorResult(err.Error()), nil
	}
	return res, nil
}
