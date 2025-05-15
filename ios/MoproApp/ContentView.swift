//
//  ContentView.swift
//  MoproApp
//
import SwiftUI
import moproFFI

func serializeOutputs(_ stringArray: [String]) -> [UInt8] {
    var bytesArray: [UInt8] = []
    let length = stringArray.count
    var littleEndianLength = length.littleEndian
    let targetLength = 32
    withUnsafeBytes(of: &littleEndianLength) {
        bytesArray.append(contentsOf: $0)
    }
    for value in stringArray {
        // TODO: should handle 254-bit input
        var littleEndian = Int32(value)!.littleEndian
        var byteLength = 0
        withUnsafeBytes(of: &littleEndian) {
            bytesArray.append(contentsOf: $0)
            byteLength = byteLength + $0.count
        }
        if byteLength < targetLength {
            let paddingCount = targetLength - byteLength
            let paddingArray = [UInt8](repeating: 0, count: paddingCount)
            bytesArray.append(contentsOf: paddingArray)
        }
    }
    return bytesArray
}

struct ContentView: View {
    @State private var textViewText = ""
    @State private var isCircomProveButtonEnabled = true
    @State private var isCircomVerifyButtonEnabled = false
    @State private var isHalo2roveButtonEnabled = true
    @State private var isHalo2VerifyButtonEnabled = false
    @State private var generatedCircomProof: CircomProof?
    @State private var circomPublicInputs: [String]?
    @State private var generatedHalo2Proof: Data?
    @State private var halo2PublicInputs: Data?
    @State private var isKeccakProveButtonEnabled = true
    @State private var isKeccakVerifyButtonEnabled = false
    @State private var generatedKeccakProof: Data?
    private let zkeyPath = Bundle.main.path(forResource: "multiplier2_final", ofType: "zkey")!
    private let srsPath = Bundle.main.path(forResource: "plonk_fibonacci_srs.bin", ofType: "")!
    private let vkPath = Bundle.main.path(forResource: "plonk_fibonacci_vk.bin", ofType: "")!
    private let pkPath = Bundle.main.path(forResource: "plonk_fibonacci_pk.bin", ofType: "")!
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Button("Prove Circom", action: runCircomProveAction).disabled(!isCircomProveButtonEnabled).accessibilityIdentifier("proveCircom")
            Button("Verify Circom", action: runCircomVerifyAction).disabled(!isCircomVerifyButtonEnabled).accessibilityIdentifier("verifyCircom")
            Button("Prove Halo2", action: runHalo2ProveAction).disabled(!isHalo2roveButtonEnabled).accessibilityIdentifier("proveHalo2")
            Button("Verify Halo2", action: runHalo2VerifyAction).disabled(!isHalo2VerifyButtonEnabled).accessibilityIdentifier("verifyHalo2")
            Button("Prove Keccak256", action: runKeccakProveAction).disabled(!isKeccakProveButtonEnabled).accessibilityIdentifier("proveKeccak")
            Button("Verify Keccak256", action: runKeccakVerifyAction).disabled(!isKeccakVerifyButtonEnabled).accessibilityIdentifier("verifyKeccak")

            ScrollView {
                Text(textViewText)
                    .padding()
                    .accessibilityIdentifier("proof_log")
            }
            .frame(height: 200)
        }
        .padding()
    }
}

extension ContentView {
    func runCircomProveAction() {
        textViewText += "Generating Circom proof... "
        do {
            // Prepare inputs
            let a = 3
            let b = 5
            let c = a*b
            let input_str: String = "{\"b\":[\"5\"],\"a\":[\"3\"]}"

            // Expected outputs
            let outputs: [String] = [String(c), String(a)]

            let start = CFAbsoluteTimeGetCurrent()

            // Generate Proof
            let generateProofResult = try generateCircomProof(zkeyPath: zkeyPath, circuitInputs: input_str, proofLib: ProofLib.arkworks)
            assert(!generateProofResult.proof.a.x.isEmpty, "Proof should not be empty")
            assert(outputs == generateProofResult.inputs, "Circuit outputs mismatch the expected outputs")

            let end = CFAbsoluteTimeGetCurrent()
            let timeTaken = end - start

            // Store the generated proof and public inputs for later verification
            generatedCircomProof = generateProofResult.proof
            circomPublicInputs = generateProofResult.inputs

            textViewText += "\(String(format: "%.3f", timeTaken))s 1️⃣\n"

            isCircomVerifyButtonEnabled = true
        } catch {
            textViewText += "\nProof generation failed: \(error.localizedDescription)\n"
        }
    }
    
    func runCircomVerifyAction() {
        guard let proof = generatedCircomProof,
              let inputs = circomPublicInputs else {
            textViewText += "Proof has not been generated yet.\n"
            return
        }
        
        textViewText += "Verifying Circom proof... "
        do {
            let start = CFAbsoluteTimeGetCurrent()
            
            let isValid = try verifyCircomProof(zkeyPath: zkeyPath, proofResult: CircomProofResult(proof: proof, inputs: inputs), proofLib: ProofLib.arkworks)
            let end = CFAbsoluteTimeGetCurrent()
            let timeTaken = end - start
            
            assert(proof.a.x.count > 0, "Proof should not be empty")
            assert(inputs.count > 0, "Inputs should not be empty")
            
            print("Ethereum Proof: \(proof)\n")
            print("Ethereum Inputs: \(inputs)\n")
            
            if isValid {
                textViewText += "\(String(format: "%.3f", timeTaken))s 2️⃣\n"
            } else {
                textViewText += "\nProof verification failed.\n"
            }
            isCircomVerifyButtonEnabled = false
        } catch let error as MoproError {
            print("\nMoproError: \(error)")
        } catch {
            print("\nUnexpected error: \(error)")
        }
    }
    
    func runHalo2ProveAction() {
        textViewText += "Generating Halo2 proof... "
        do {
            // Prepare inputs
            var inputs = [String: [String]]()
            let out = 55
            inputs["out"] = [String(out)]
            
            let start = CFAbsoluteTimeGetCurrent()
            
            // Generate Proof
            let generateProofResult = try generateHalo2Proof(srsPath: srsPath, pkPath: pkPath, circuitInputs: inputs)
            assert(!generateProofResult.proof.isEmpty, "Proof should not be empty")
            assert(!generateProofResult.inputs.isEmpty, "Inputs should not be empty")

            
            let end = CFAbsoluteTimeGetCurrent()
            let timeTaken = end - start
            
            // Store the generated proof and public inputs for later verification
            generatedHalo2Proof = generateProofResult.proof
            halo2PublicInputs = generateProofResult.inputs
            
            textViewText += "\(String(format: "%.3f", timeTaken))s 1️⃣\n"
            
            isHalo2VerifyButtonEnabled = true
        } catch {
            textViewText += "\nProof generation failed: \(error.localizedDescription)\n"
        }
    }
    
    func runHalo2VerifyAction() {
        guard let proof = generatedHalo2Proof,
              let inputs = halo2PublicInputs else {
            textViewText += "Proof has not been generated yet.\n"
            return
        }
        
        textViewText += "Verifying Halo2 proof... "
        do {
            let start = CFAbsoluteTimeGetCurrent()
            
            let isValid = try verifyHalo2Proof(
              srsPath: srsPath, vkPath: vkPath, proof: proof, publicInput: inputs)
            let end = CFAbsoluteTimeGetCurrent()
            let timeTaken = end - start

            
            if isValid {
                textViewText += "\(String(format: "%.3f", timeTaken))s 2️⃣\n"
            } else {
                textViewText += "\nProof verification failed.\n"
            }
            isHalo2VerifyButtonEnabled = false
        } catch let error as MoproError {
            print("\nMoproError: \(error)")
        } catch {
            print("\nUnexpected error: \(error)")
        }
    }

    func runKeccakProveAction() {
        textViewText += "Generating Keccak256 proof... "

        guard let srsPath = Bundle.main.path(forResource: "zkemail_srs", ofType: "local") else {
            DispatchQueue.main.async {
                self.textViewText += "\nError: Could not find srs.local in app bundle.\n"
            }
            return
        }

        let example_x_values: [UInt8] = [123, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        let example_result_values: [UInt8] = [117, 161, 42, 122, 171, 96, 25, 82, 239, 113, 221, 109, 167, 23, 37, 234, 164, 235, 120, 131, 9, 96, 103, 84, 108, 138, 227, 249, 156, 201, 34, 46]
        let inputsArray: [UInt8] = example_x_values + example_result_values
        let inputsData = Data(inputsArray)

        // Run in background thread to avoid blocking the UI
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let start = CFAbsoluteTimeGetCurrent()

                let proofData = try! proveKeccak256Simple(srsPath: srsPath, inputs: inputsData)
                assert(!proofData.isEmpty, "Proof should not be empty")

                let end = CFAbsoluteTimeGetCurrent()
                let timeTaken = end - start

                // Update UI on the main thread
                DispatchQueue.main.async {
                    self.generatedKeccakProof = proofData
                    self.textViewText += "\(String(format: "%.3f", timeTaken))s 1️⃣\n"
                    self.isKeccakVerifyButtonEnabled = true
                    self.isKeccakProveButtonEnabled = false // Disable prove button after successful proof
                }
            } catch {
                // Update UI on the main thread
                DispatchQueue.main.async {
                    self.textViewText += "\nProof generation failed: \(error.localizedDescription)\n"
                }
            }
        }
    }

    func runKeccakVerifyAction() {
        guard let proofData = generatedKeccakProof else {
            textViewText += "Proof has not been generated yet.\n"
            return
        }

        guard let srsPath = Bundle.main.path(forResource: "zkemail_srs", ofType: "local") else {
            DispatchQueue.main.async {
                self.textViewText += "\nError: Could not find srs.local in app bundle.\n"
            }
            return
        }

        textViewText += "Verifying Keccak256 proof... "

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let start = CFAbsoluteTimeGetCurrent()

                // Pass proofData (which is Data) directly to the FFI function
                let isValid = try! verifyKeccak256Simple(srsPath: srsPath, proof: proofData)
                let end = CFAbsoluteTimeGetCurrent()
                let timeTaken = end - start

                // Update UI on the main thread
                DispatchQueue.main.async {
                    if isValid {
                        self.textViewText += "\(String(format: "%.3f", timeTaken))s 2️⃣\n"
                    } else {
                        self.textViewText += "\nProof verification failed.\n"
                    }
                    self.isKeccakVerifyButtonEnabled = false
                    // Optionally re-enable prove button or handle state differently after verification
                     self.isKeccakProveButtonEnabled = true 
                }
            } catch let error as MoproError {
                // Update UI on the main thread
                DispatchQueue.main.async {
                    self.textViewText += "\nMoproError: \(error)\n"
                    self.isKeccakVerifyButtonEnabled = false // Keep verify disabled on error
                }
            } catch {
                // Update UI on the main thread
                DispatchQueue.main.async {
                    self.textViewText += "\nUnexpected error: \(error.localizedDescription)\n"
                    self.isKeccakVerifyButtonEnabled = false // Keep verify disabled on error
                }
            }
        }
    }
}

