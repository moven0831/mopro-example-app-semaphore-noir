//
//  ContentView.swift
//  MoproApp
//
import SwiftUI
import moproFFI

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
    @State private var isSemaphoreProveButtonEnabled = true
    @State private var isSemaphoreVerifyButtonEnabled = false
    @State private var generatedSemaphoreProof: Data?
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
            Button("Prove Semaphore", action: runSemaphoreProveAction).disabled(!isSemaphoreProveButtonEnabled).accessibilityIdentifier("proveSemaphore")
            Button("Verify Semaphore", action: runSemaphoreVerifyAction).disabled(!isSemaphoreVerifyButtonEnabled).accessibilityIdentifier("verifySemaphore")

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
            
            print("Ethereum Proof: \(proof)\n")
            
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

    func runSemaphoreProveAction() {
        textViewText += "Generating Semaphore proof... "

        guard let semaphoreSrsPath = Bundle.main.path(forResource: "semaphore", ofType: "srs") else {
            DispatchQueue.main.async {
                self.textViewText += "\nError: Could not find semaphore.srs in app bundle.\n"
            }
            return
        }

        // Load inputs from semaphore_input.json
        guard let inputPath = Bundle.main.path(forResource: "semaphore_input", ofType: "json") else {
            DispatchQueue.main.async {
                self.textViewText += "\nError: Could not find semaphore_input.json in app bundle.\n"
            }
            return
        }

        var inputsVec: [String] = []
        do {
            let inputData = try Data(contentsOf: URL(fileURLWithPath: inputPath))
            if let json = try JSONSerialization.jsonObject(with: inputData, options: []) as? [String: Any] {
                if let secretKey = json["secret_key"] as? String { inputsVec.append(secretKey) }
                if let indexBits = json["index_bits"] as? [String] { inputsVec.append(contentsOf: indexBits) }
                if let hashPath = json["hash_path"] as? [String] { inputsVec.append(contentsOf: hashPath) }
                if let merkleProofLength = json["merkle_proof_length"] as? String { inputsVec.append(merkleProofLength) }
                if let hashedScope = json["hashed_scope"] as? String { inputsVec.append(hashedScope) }
                if let hashedMessage = json["hashed_message"] as? String { inputsVec.append(hashedMessage) }
            }
        } catch {
            DispatchQueue.main.async {
                self.textViewText += "\nError parsing semaphore_input.json: \(error.localizedDescription)\n"
            }
            return
        }

        // Run in background thread to avoid blocking the UI
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let start = CFAbsoluteTimeGetCurrent()

                // Call the FFI function proveSemaphore
                // The FFI function name might be prove_semaphore based on lib.rs, ensure moproFFI exposes it as proveSemaphore
                let proofData = try! proveSemaphore(srsPath: semaphoreSrsPath, inputs: inputsVec)
                assert(!proofData.isEmpty, "Proof should not be empty")

                let end = CFAbsoluteTimeGetCurrent()
                let timeTaken = end - start

                // Update UI on the main thread
                DispatchQueue.main.async {
                    self.generatedSemaphoreProof = Data(proofData) // Assuming proveSemaphore returns [UInt8]
                    self.textViewText += "\(String(format: "%.3f", timeTaken))s 1️⃣\n"
                    self.isSemaphoreVerifyButtonEnabled = true
                    self.isSemaphoreProveButtonEnabled = false // Disable prove button after successful proof
                }
            } catch {
                // Update UI on the main thread
                DispatchQueue.main.async {
                    self.textViewText += "\nProof generation failed: \(error.localizedDescription)\n"
                }
            }
        }
    }

    func runSemaphoreVerifyAction() {
        guard let proofData = generatedSemaphoreProof else {
            textViewText += "Proof has not been generated yet.\n"
            return
        }

        guard let semaphoreSrsPath = Bundle.main.path(forResource: "semaphore", ofType: "srs") else {
            DispatchQueue.main.async {
                self.textViewText += "\nError: Could not find semaphore.srs in app bundle.\n"
            }
            return
        }

        textViewText += "Verifying Semaphore proof... "

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let start = CFAbsoluteTimeGetCurrent()

                // Call the FFI function verifySemaphore
                // The FFI function name might be verify_semaphore based on lib.rs, ensure moproFFI exposes it as verifySemaphore
                let isValid = try! verifySemaphore (srsPath: semaphoreSrsPath, proof: proofData)
                let end = CFAbsoluteTimeGetCurrent()
                let timeTaken = end - start

                // Update UI on the main thread
                DispatchQueue.main.async {
                    if isValid {
                        self.textViewText += "\(String(format: "%.3f", timeTaken))s 2️⃣\n"
                    } else {
                        self.textViewText += "\nProof verification failed.\n"
                    }
                    self.isSemaphoreVerifyButtonEnabled = false
                    self.isSemaphoreProveButtonEnabled = true
                }
            } catch let error as MoproError {
                // Update UI on the main thread
                DispatchQueue.main.async {
                    self.textViewText += "\nMoproError: \(error)\n"
                    self.isSemaphoreVerifyButtonEnabled = false
                }
            } catch {
                // Update UI on the main thread
                DispatchQueue.main.async {
                    self.textViewText += "\nUnexpected error: \(error.localizedDescription)\n"
                    self.isSemaphoreVerifyButtonEnabled = false
                }
            }
        }
    }
}

