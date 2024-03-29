package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"html/template"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
)

var applyFlag bool

func main() {
	flag.BoolVar(&applyFlag, "apply", false, "write to file")
	flag.Parse()

	bytecode, err := getForgeConnectorBytecode()
	if err != nil {
		fmt.Printf("failed to get forge wrapper bytecode: %v\n", err)
		os.Exit(1)
	}

	precompileNames, err := getPrecompileNames()
	if err != nil {
		fmt.Printf("failed to get precompile names: %v\n", err)
		os.Exit(1)
	}

	if err := applyTemplate(bytecode, precompileNames); err != nil {
		fmt.Printf("failed to apply template: %v\n", err)
		os.Exit(1)
	}
}

var templateFile = `// SPDX-License-Identifier: UNLICENSED
// DO NOT edit this file. Code generated by forge-gen.
pragma solidity ^0.8.8;

import "../suavelib/Suave.sol";

interface registryVM {
    function etch(address, bytes calldata) external;
}

library Registry {
    registryVM constant vm = registryVM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function enableLib(address addr) public {
        // code for Wrapper
        bytes memory code =
            hex"{{.Bytecodes.Connector}}";
        vm.etch(addr, code);

		// enable is confidential wrapper
		bytes memory confidentialCode =
			hex"{{.Bytecodes.Confidential}}";
		vm.etch(Suave.CONFIDENTIAL_INPUTS, confidentialCode);
    }

    function enable() public {
		{{range .PrecompileNames}}
		enableLib(Suave.{{.}});
		{{- end}}
    }
}`

func applyTemplate(bytecodes *forgeWrapperBytecodes, precompileNames []string) error {
	t, err := template.New("template").Parse(templateFile)
	if err != nil {
		return err
	}

	input := map[string]interface{}{
		"Bytecodes":       bytecodes,
		"PrecompileNames": precompileNames,
	}

	var outputRaw bytes.Buffer
	if err = t.Execute(&outputRaw, input); err != nil {
		return err
	}

	str := outputRaw.String()
	if str, err = formatSolidity(str); err != nil {
		return err
	}

	if applyFlag {
		if err := os.WriteFile(resolvePath("../../src/forge/Registry.sol"), []byte(str), 0644); err != nil {
			return err
		}
	} else {
		fmt.Println(str)
	}
	return nil
}

type forgeWrapperBytecodes struct {
	Connector    string
	Confidential string
}

func getForgeConnectorBytecode() (*forgeWrapperBytecodes, error) {
	mirror := func(from, to string) error {
		connectorSrc, err := os.ReadFile(resolvePath(from))
		if err != nil {
			return err
		}
		if err := writeFile(resolvePath(to), connectorSrc); err != nil {
			return err
		}
		return nil
	}

	// mirror the Connector.sol contract to ./src
	if err := mirror("../../src/forge/Connector.sol", "./src-forge-test/Connector.sol"); err != nil {
		return nil, err
	}
	// mirror the is confidential solver
	if err := mirror("../../src/forge/ConfidentialInputs.sol", "./src-forge-test/ConfidentialInputs.sol"); err != nil {
		return nil, err
	}

	// compile the Connector contract with forge and the local configuration
	if _, err := execForgeCommand([]string{"build", "--config-path", resolvePath("./foundry.toml")}, ""); err != nil {
		return nil, err
	}

	decodeBytecode := func(name string) (string, error) {
		abiContent, err := os.ReadFile(resolvePath(name))
		if err != nil {
			return "", err
		}

		var abiArtifact struct {
			DeployedBytecode struct {
				Object string
			}
		}
		if err := json.Unmarshal(abiContent, &abiArtifact); err != nil {
			return "", err
		}

		bytecode := abiArtifact.DeployedBytecode.Object[2:]
		return bytecode, nil
	}

	res := &forgeWrapperBytecodes{}
	var err error

	if res.Connector, err = decodeBytecode("./out/Connector.sol/Connector.json"); err != nil {
		return nil, err
	}
	if res.Confidential, err = decodeBytecode("./out/ConfidentialInputs.sol/ConfidentialInputsWrapper.json"); err != nil {
		return nil, err
	}

	return res, nil
}

func getPrecompileNames() ([]string, error) {
	content, err := os.ReadFile("./src/suavelib/Suave.sol")
	if err != nil {
		return nil, err
	}

	addrRegexp := regexp.MustCompile(`constant\s+([A-Za-z_]\w*)\s+=`)

	matches := addrRegexp.FindAllStringSubmatch(string(content), -1)

	names := []string{}
	for _, match := range matches {
		if len(match) > 1 {
			name := strings.TrimSpace(match[1])
			if name == "ANYALLOWED" {
				continue
			}
			if name == "CONFIDENTIAL_INPUTS" {
				continue
			}
			names = append(names, name)
		}
	}

	return names, nil
}

func formatSolidity(code string) (string, error) {
	return execForgeCommand([]string{"fmt", "--raw", "-"}, code)
}

func execForgeCommand(args []string, stdin string) (string, error) {
	_, err := exec.LookPath("forge")
	if err != nil {
		return "", fmt.Errorf("forge command not found in PATH: %v", err)
	}

	// Create a command to run the forge command
	cmd := exec.Command("forge", args...)

	// Set up input from stdin
	if stdin != "" {
		cmd.Stdin = bytes.NewBufferString(stdin)
	}

	// Set up output buffer
	var outBuf, errBuf bytes.Buffer
	cmd.Stdout = &outBuf
	cmd.Stderr = &errBuf

	// Run the command
	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("error running command: %v, %s", err, errBuf.String())
	}

	return outBuf.String(), nil
}

// writeFile creates the parent directory if not found
// and then writes the file to the path.
func writeFile(path string, content []byte) error {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}

	if err := os.WriteFile(path, content, 0644); err != nil {
		return err
	}
	return nil
}

func resolvePath(path string) string {
	// Get the caller's file path.
	_, filename, _, _ := runtime.Caller(1)

	// Resolve the directory of the caller's file.
	callerDir := filepath.Dir(filename)

	// Construct the absolute path to the target file.
	return filepath.Join(callerDir, path)
}
