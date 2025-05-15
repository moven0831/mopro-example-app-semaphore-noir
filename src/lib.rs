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
pub fn prove_keccak256_simple() -> Vec<u8> {
    const KECCAK256_JSON: &str = include_str!("../circuit/target/circuit.json");
    let bytecode_json: serde_json::Value = serde_json::from_str(&KECCAK256_JSON).unwrap();
    let bytecode = bytecode_json["bytecode"].as_str().unwrap();

    // Setup SRS
    setup_srs_from_bytecode(bytecode, None, false).unwrap();

    let witness_arrays: Vec<[&str; 32]> = vec![
        ["123", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0", "0"], // x
        ["117", "161", "42", "122", "171", "96", "25", "82", "239", "113", "221", "109", "167", "23", "37", "234", "164", "235", "120", "131", "9", "96", "103", "84", "108", "138", "227", "249", "156", "201", "34", "46"] // result
    ];
    let witness_vec_str: Vec<&str> = witness_arrays.into_iter().flatten().collect();

    let initial_witness = from_vec_str_to_witness_map(witness_vec_str).unwrap();

    // Start timing the proof generation
    let start = std::time::Instant::now();
    let proof = prove_ultra_honk(bytecode, initial_witness, false).unwrap();

    println!("Keccak256 proof generation time: {:?}", start.elapsed());

    proof
}

#[uniffi::export]
pub fn verify_keccak256_simple(proof: Vec<u8>) -> bool {
    // Assuming the Keccak256 circuit JSON is located at this path
    const KECCAK256_JSON: &str = include_str!("../circuit/target/circuit.json");
    let bytecode_json: serde_json::Value = serde_json::from_str(&KECCAK256_JSON).unwrap();
    let bytecode = bytecode_json["bytecode"].as_str().unwrap();

    // Setup SRS
    setup_srs_from_bytecode(bytecode, None, false).unwrap();

    // Get the verification key
    let vk = get_honk_verification_key(bytecode, false).unwrap();

    // Start timing the proof verification
    let start = std::time::Instant::now();
    let verdict = verify_ultra_honk(proof, vk).unwrap();

    println!("Keccak256 proof verification time: {:?}", start.elapsed());
    println!("Keccak256 proof verification verdict: {}", verdict);

    verdict
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_prove_and_verify_keccak256_simple() {
        let proof = prove_keccak256_simple();
        assert!(!proof.is_empty(), "Proof should not be empty");
        let is_valid = verify_keccak256_simple(proof);
        assert!(is_valid, "Proof verification should succeed");
    }
}
