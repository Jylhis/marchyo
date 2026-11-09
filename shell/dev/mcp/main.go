// Command marchyo-shell-mcp serves the marchyo shell dev sandbox over MCP on stdio.
package main

import (
	"context"
	"flag"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
)

func itoa(n int) string { return strconv.Itoa(n) }

func main() {
	log.SetFlags(0)
	log.SetPrefix("marchyo-shell-mcp: ")
	root := flag.String("root", ".", "marchyo root (contains shell/dev/sandbox)")
	flag.Parse()

	abs, err := filepath.Abs(*root)
	if err != nil {
		log.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(abs, "shell", "dev", "sandbox")); err != nil {
		log.Fatalf("not a marchyo root: %v", err)
	}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()
	s := newServer(devenvRunner(abs), filepath.Join(os.TempDir(), "marchyo-shell-mcp"))
	if err := serve(ctx, s, os.Stdin, os.Stdout); err != nil {
		log.Fatal(err)
	}
}
