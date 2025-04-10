#ifndef WATERMARK_H
#define WATERMARK_H

#include <string>
#include <vector>
#include <opencv2/opencv.hpp>

/**
 * Embeds a text message into an image using the border-hash method with CUDA acceleration.
 * 
 * @param inputPath Path to the input image
 * @param outputPath Path to save the watermarked image
 * @param message The text message to embed
 * @return Number of bits in the embedded message
 */
int embedMessage(const std::string& inputPath, const std::string& outputPath, const std::string& message);

/**
 * Extracts a hidden message from a watermarked image using CUDA acceleration.
 * 
 * @param inputPath Path to the watermarked image
 * @return The extracted text message
 */
std::string extractMessage(const std::string& inputPath);

#endif // WATERMARK_H