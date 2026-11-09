package main

import (
	"bytes"
	"context"
	"errors"
	"os/exec"
	"path/filepath"
)

// Runner runs one dev script (sandbox or shot) and returns its output.
type Runner func(ctx context.Context, script string, args ...string) (string, string, error)

type exitError struct{ Code int }

func (e *exitError) Error() string { return "exit status " + itoa(e.Code) }

// devenvRunner runs scripts inside the marchyo devenv, which provides bwrap, grim, jq and
// quickshell. Arguments are separate argv entries, never parsed by a shell.
func devenvRunner(root string) Runner {
	return func(ctx context.Context, script string, args ...string) (string, string, error) {
		argv := append([]string{"shell", "--", filepath.Join("shell", "dev", script)}, args...)
		cmd := exec.CommandContext(ctx, "devenv", argv...)
		cmd.Dir = root
		var stdout, stderr bytes.Buffer
		cmd.Stdout, cmd.Stderr = &stdout, &stderr
		err := cmd.Run()
		if ctx.Err() != nil {
			err = ctx.Err()
		} else if ee, ok := errors.AsType[*exec.ExitError](err); ok {
			err = &exitError{Code: ee.ExitCode()}
		}
		return stdout.String(), stderr.String(), err
	}
}
