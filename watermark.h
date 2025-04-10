#ifndef WATERMARK_H
#define WATERMARK_H

#include <string>
#include <vector>
#include <opencv2/opencv.hpp>
#include <utility>

/**
 * Structure to hold timing information for benchmarking
 */
struct TimingInfo {
    float gpuTime;       // GPU execution time in milliseconds
    float totalTime;     // Total execution time in milliseconds
};

/**
 * Embeds a text message into an image using the border-hash method with CUDA acceleration.
 * 
 * @param inputPath Path to the input image
 * @param outputPath Path to save the watermarked image
 * @param message The text message to embed
 * @return TimingInfo structure containing GPU and total execution time
 */
TimingInfo embedMessage(const std::string& inputPath, const std::string& outputPath, const std::string& message);

/**
 * Extracts a hidden message from a watermarked image using CUDA acceleration.
 * 
 * @param inputPath Path to the watermarked image
 * @return A pair containing the extracted text message and timing information
 */
std::pair<std::string, TimingInfo> extractMessage(const std::string& inputPath);

#endif // WATERMARK_H