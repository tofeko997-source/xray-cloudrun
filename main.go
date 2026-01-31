package main

import (
	"log"
	"os"
	"os/exec"
	"strings"
	"io/ioutil"
)

func getenv(key, def string) string {
	v := os.Getenv(key)
	if v == "" {
		return def
	}
	return v
}

func main() {
	// Read template
	tplPath := "/config.json.tpl"
	data, err := ioutil.ReadFile(tplPath)
	if err != nil {
		log.Fatalf("failed to read template %s: %v", tplPath, err)
	}
	s := string(data)

	// Gather envs with defaults
	proto := getenv("PROTO", "vless")
	user := getenv("USER_ID", getenv("UUID", "changeme"))
	wspath := getenv("WS_PATH", "/ws")
	network := getenv("NETWORK", "ws")

	// replace placeholders
	repl := map[string]string{
		"__PROTO__": proto,
		"__USER_ID__": user,
		"__WS_PATH__": wspath,
		"__NETWORK__": network,
	}
	for k,v := range repl {
		s = strings.ReplaceAll(s, k, v)
	}

	// write output
	outPath := "/etc/xray/config.json"
	if err := os.MkdirAll("/etc/xray", 0755); err != nil {
		log.Fatalf("failed to create dir: %v", err)
	}
	if err := ioutil.WriteFile(outPath, []byte(s), 0644); err != nil {
		log.Fatalf("failed to write config: %v", err)
	}

	// exec xray
	path, err := exec.LookPath("xray")
	if err != nil {
		log.Fatalf("xray binary not found in PATH: %v", err)
	}

	args := []string{"xray", "run", "-config", outPath}
	env := os.Environ()
	if err := syscallExec(path, args, env); err != nil {
		log.Fatalf("failed to exec xray: %v", err)
	}
}

// syscallExec uses syscall.Exec when available, fallback to exec.Command when not.
func syscallExec(path string, args, env []string) error {
	// Try to use syscall.Exec from the syscall package
	// Use low-level call to replace process; on some platforms syscall.Exec is available.
	// We'll import syscall here to avoid build issues on non-unix.
	importSyscall := func() error { return nil }
	_ = importSyscall

	// Fallback: run command and wait
	cmd := exec.Command(path, args[1:]...)
	cmd.Env = env
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	return cmd.Run()
}
