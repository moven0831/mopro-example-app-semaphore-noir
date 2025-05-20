package com.example.moproapp

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.json.JSONObject
import uniffi.mopro.proveSemaphore
import uniffi.mopro.verifySemaphore
import java.io.File
import java.io.InputStream

@Composable
fun SemaphoreComponent() {
    val context = LocalContext.current
    var provingTime by remember { mutableStateOf("") }
    var proofResult by remember { mutableStateOf("") }
    var verificationTime by remember { mutableStateOf("") }
    var verificationResult by remember { mutableStateOf("") }
    var proofBytes by remember { mutableStateOf<ByteArray?>(null) }

    // Status states
    var isGeneratingProof by remember { mutableStateOf(false) }
    var isVerifyingProof by remember { mutableStateOf(false) }
    var statusMessage by remember { mutableStateOf("Ready to generate proof") }

    val srsFileName = "semaphore.srs"

    fun prepareSemaphoreInputs(): List<String> {
        val inputs = mutableListOf<String>()
        try {
            context.assets.open("semaphore_input.json").bufferedReader().use { reader ->
                val jsonString = reader.readText()
                val jsonObject = JSONObject(jsonString)

                inputs.add(jsonObject.getString("secret_key"))

                val indexBitsArray = jsonObject.getJSONArray("index_bits")
                for (i in 0 until indexBitsArray.length()) {
                    inputs.add(indexBitsArray.getString(i))
                }

                val hashPathArray = jsonObject.getJSONArray("hash_path")
                for (i in 0 until hashPathArray.length()) {
                    inputs.add(hashPathArray.getString(i))
                }

                inputs.add(jsonObject.getString("merkle_proof_length"))
                inputs.add(jsonObject.getString("hashed_scope"))
                inputs.add(jsonObject.getString("hashed_message"))
            }
        } catch (e: Exception) {
            e.printStackTrace()
            statusMessage = "Error reading semaphore_input.json: ${e.message}"
        }
        return inputs
    }

    // Function to ensure SRS file is available
    fun prepareSrsFile(): String {
        val srsFile = File(context.filesDir, srsFileName)
        if (!srsFile.exists()) {
            try {
                context.assets.open(srsFileName).use { input ->
                    srsFile.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        return srsFile.absolutePath
    }

    Box(modifier = Modifier.fillMaxSize().padding(16.dp), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = "Semaphore (Noir)", // Updated Title
                modifier = Modifier.padding(bottom = 20.dp),
                fontWeight = FontWeight.Bold,
                fontSize = 22.sp
            )

            Text(
                text = statusMessage,
                modifier = Modifier.padding(bottom = 24.dp),
                textAlign = TextAlign.Center,
                fontSize = 16.sp,
                fontWeight = if (isGeneratingProof || isVerifyingProof) FontWeight.Bold else FontWeight.Normal
            )

            if (isGeneratingProof || isVerifyingProof) {
                CircularProgressIndicator(
                    modifier = Modifier.padding(bottom = 16.dp)
                )
            }

            Button(
                onClick = {
                    isGeneratingProof = true
                    provingTime = ""
                    proofResult = ""
                    statusMessage = "Generating proof... This may take some time"

                    Thread(
                        Runnable {
                            try {
                                val srsPath = prepareSrsFile()
                                val inputs = prepareSemaphoreInputs()

                                if (inputs.isEmpty() && !statusMessage.startsWith("Error reading")) {
                                    statusMessage = "Failed to prepare inputs. Check semaphore_prover_inputs.json."
                                    isGeneratingProof = false
                                    return@Runnable
                                } else if (statusMessage.startsWith("Error reading")) {
                                     isGeneratingProof = false
                                     return@Runnable
                                }

                                val startTime = System.currentTimeMillis()
                                proofBytes = proveSemaphore(srsPath, inputs)
                                val endTime = System.currentTimeMillis()
                                val duration = endTime - startTime

                                provingTime = "Proving time: $duration ms"
                                proofResult = "Proof generated: ${proofBytes?.size ?: 0} bytes"
                                statusMessage = "Proof generation completed"
                            } catch (e: Exception) {
                                provingTime = "Proving failed"
                                proofResult = "Error: ${e.message}"
                                statusMessage = "Proof generation failed"
                                e.printStackTrace()
                            } finally {
                                isGeneratingProof = false
                            }
                        }
                    ).start()
                },
                modifier = Modifier.padding(top = 20.dp).testTag("noirGenerateProofButton"),
                enabled = !isGeneratingProof && !isVerifyingProof
            ) {
                Text(text = "Generate Semaphore Proof")
            }

            Spacer(modifier = Modifier.height(16.dp))

            Button(
                onClick = {
                    isVerifyingProof = true
                    verificationTime = ""
                    verificationResult = ""
                    statusMessage = "Verifying proof..."

                    Thread(
                        Runnable {
                            try {
                                proofBytes?.let { proof ->
                                    val srsPath = prepareSrsFile()

                                    val startTime = System.currentTimeMillis()
                                    val result = verifySemaphore(srsPath, proof)
                                    val endTime = System.currentTimeMillis()
                                    val duration = endTime - startTime

                                    verificationTime = "Verification time: $duration ms"
                                    verificationResult = "Verification result: $result"
                                    if (result)
                                        statusMessage = "Proof verified successfully!"
                                    else
                                        statusMessage = "Proof verification failed!"
                                } ?: run {
                                    verificationResult = "No proof available"
                                    statusMessage = "Please generate a proof first"
                                }
                            } catch (e: Exception) {
                                verificationTime = "Verification failed"
                                verificationResult = "Error: ${e.message}"
                                statusMessage = "Proof verification error"
                                e.printStackTrace()
                            } finally {
                                isVerifyingProof = false
                            }
                        }
                    ).start()
                },
                modifier = Modifier.padding(top = 20.dp).testTag("noirVerifyProofButton"),
                enabled = !isGeneratingProof && !isVerifyingProof && proofBytes != null
            ) {
                Text(text = "Verify Semaphore Proof")
            }

            Spacer(modifier = Modifier.height(40.dp))

            if (provingTime.isNotEmpty() || proofResult.isNotEmpty() || 
                verificationTime.isNotEmpty() || verificationResult.isNotEmpty()) {

                Text(
                    text = "Results",
                    fontWeight = FontWeight.Bold,
                    fontSize = 18.sp,
                    modifier = Modifier.padding(bottom = 8.dp)
                )

                if (provingTime.isNotEmpty()) {
                    Text(
                        text = provingTime,
                        modifier = Modifier.padding(top = 4.dp).width(280.dp),
                        textAlign = TextAlign.Center
                    )
                }

                if (proofResult.isNotEmpty()) {
                    Text(
                        text = proofResult,
                        modifier = Modifier.padding(top = 4.dp).width(280.dp),
                        textAlign = TextAlign.Center
                    )
                }

                if (verificationTime.isNotEmpty()) {
                    Text(
                        text = verificationTime,
                        modifier = Modifier.padding(top = 4.dp).width(280.dp),
                        textAlign = TextAlign.Center
                    )
                }

                if (verificationResult.isNotEmpty()) {
                    Text(
                        text = verificationResult,
                        modifier = Modifier.padding(top = 4.dp).width(280.dp),
                        textAlign = TextAlign.Center,
                        fontWeight = if (verificationResult.contains("true")) FontWeight.Bold else FontWeight.Normal
                    )
                }
            }
        }
    }
} 