// Here we're calling a macro exported with Uniffi. This macro will
// write some functions and bind them to FFI type. These
// functions will invoke the `get_circom_wtns_fn` generated below.
mopro_ffi::app!();

use noir::{
    barretenberg::{
        prove::prove_ultra_honk,
        srs::setup_srs_from_bytecode,
        utils::get_honk_verification_key,
        verify::verify_ultra_honk,
    },
    witness::from_vec_str_to_witness_map,
};

#[uniffi::export]
pub fn prove_semaphore(srs_path: String, inputs: Vec<String>) -> Vec<u8> {
    const SEMAPHORE_JSON: &str = include_str!("../circuit/target/circuit.json");
    let bytecode_json: serde_json::Value = serde_json::from_str(&SEMAPHORE_JSON).unwrap();
    let bytecode = bytecode_json["bytecode"].as_str().unwrap();

    setup_srs_from_bytecode(bytecode, Some(&srs_path), false).unwrap();

    let witness_vec_ref_str: Vec<&str> = inputs.iter().map(|s| s.as_str()).collect();

    let initial_witness = from_vec_str_to_witness_map(witness_vec_ref_str).unwrap();

    let start = std::time::Instant::now();
    let proof = prove_ultra_honk(bytecode, initial_witness, false).unwrap();

    println!("Semaphore proof generation time: {:?}", start.elapsed());

    proof
}

#[uniffi::export]
pub fn verify_semaphore(srs_path: String, proof: Vec<u8>) -> bool {
    const SEMAPHORE_JSON: &str = include_str!("../circuit/target/circuit.json");
    let bytecode_json: serde_json::Value = serde_json::from_str(&SEMAPHORE_JSON).unwrap();
    let bytecode = bytecode_json["bytecode"].as_str().unwrap();

    setup_srs_from_bytecode(bytecode, Some(&srs_path), false).unwrap();

    let vk = get_honk_verification_key(bytecode, false).unwrap();

    let start = std::time::Instant::now();
    let verdict = verify_ultra_honk(proof, vk).unwrap();

    println!("Semaphore proof verification time: {:?}", start.elapsed());
    println!("Semaphore proof verification verdict: {}", verdict);

    verdict
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde::Deserialize;
    use std::fs;
    use toml;

    #[derive(Deserialize, Debug)]
    struct ProverInput {
        secret_key: String,
        index_bits: Vec<String>,
        hash_path: Vec<String>,
        merkle_proof_length: String,
        hashed_scope: String,
        hashed_message: String,
    }

    #[test]
    fn test_prove_and_verify_semaphore() {
        let srs_path = "test-vectors/noir/semaphore.srs".to_string();

        let toml_str = fs::read_to_string("circuit/Prover.toml").expect("Failed to read Prover.toml");
        let prover_input: ProverInput = toml::from_str(&toml_str).expect("Failed to parse Prover.toml");

        let mut inputs: Vec<String> = Vec::new();
        inputs.push(prover_input.secret_key);
        inputs.extend(prover_input.index_bits);
        inputs.extend(prover_input.hash_path);
        inputs.push(prover_input.merkle_proof_length);
        inputs.push(prover_input.hashed_scope);
        inputs.push(prover_input.hashed_message);

        let proof = prove_semaphore(srs_path.clone(), inputs);
        assert!(!proof.is_empty(), "Proof should not be empty");
        let is_valid = verify_semaphore(srs_path, proof);
        assert!(is_valid, "Proof verification should succeed");
    }
}