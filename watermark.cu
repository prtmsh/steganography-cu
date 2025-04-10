#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <random>
#include <algorithm>
#include <cuda_runtime.h>
#include <opencv2/opencv.hpp>
#include <openssl/sha.h>
#include <sstream>
#include <iomanip>

// Structure to hold pixel position
struct PixelPosition {
    int y;
    int x;
};

// CUDA kernel for embedding bits into the LSB of the blue channel
__global__ void embedBitsKernel(unsigned char* image, int width, int height, 
                               const PixelPosition* positions, const unsigned char* data, 
                               int totalBits) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < totalBits) {
        int byteIndex = idx / 8;
        int bitPos = 7 - (idx % 8);  // MSB first
        
        int y = positions[idx].y;
        int x = positions[idx].x;
        int pixelIdx = (y * width + x) * 3;  // 3 channels (BGR)
        
        // Get the bit from the data
        unsigned char bit = (data[byteIndex] >> bitPos) & 1;
        
        // Clear the LSB of the blue channel and set it to the current bit
        image[pixelIdx] = (image[pixelIdx] & 0xFE) | bit;
    }
}

// CUDA kernel for extracting bits from the LSB of the blue channel
__global__ void extractBitsKernel(const unsigned char* image, int width, int height,
                                 const PixelPosition* positions, unsigned char* bits,
                                 int totalBits) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < totalBits) {
        int y = positions[idx].y;
        int x = positions[idx].x;
        int pixelIdx = (y * width + x) * 3;  // 3 channels (BGR)
        
        // Extract the LSB of the blue channel
        bits[idx] = image[pixelIdx] & 1;
    }
}

// Function to compute SHA-256 hash from border pixels
std::string computeBorderHash(const cv::Mat& image) {
    int height = image.rows;
    int width = image.cols;
    
    // Extract border pixels
    std::vector<unsigned char> borderPixels;
    
    // Top row
    for (int x = 0; x < width; x++) {
        cv::Vec3b pixel = image.at<cv::Vec3b>(0, x);
        borderPixels.push_back(pixel[0]);
        borderPixels.push_back(pixel[1]);
        borderPixels.push_back(pixel[2]);
    }
    
    // Bottom row
    for (int x = 0; x < width; x++) {
        cv::Vec3b pixel = image.at<cv::Vec3b>(height - 1, x);
        borderPixels.push_back(pixel[0]);
        borderPixels.push_back(pixel[1]);
        borderPixels.push_back(pixel[2]);
    }
    
    // Left column (excluding corners)
    for (int y = 1; y < height - 1; y++) {
        cv::Vec3b pixel = image.at<cv::Vec3b>(y, 0);
        borderPixels.push_back(pixel[0]);
        borderPixels.push_back(pixel[1]);
        borderPixels.push_back(pixel[2]);
    }
    
    // Right column (excluding corners)
    for (int y = 1; y < height - 1; y++) {
        cv::Vec3b pixel = image.at<cv::Vec3b>(y, width - 1);
        borderPixels.push_back(pixel[0]);
        borderPixels.push_back(pixel[1]);
        borderPixels.push_back(pixel[2]);
    }
    
    // Compute SHA-256 hash
    unsigned char hash[SHA256_DIGEST_LENGTH];
    SHA256_CTX sha256;
    SHA256_Init(&sha256);
    SHA256_Update(&sha256, borderPixels.data(), borderPixels.size());
    SHA256_Final(hash, &sha256);
    
    // Convert hash to hexadecimal string
    std::stringstream ss;
    for (int i = 0; i < SHA256_DIGEST_LENGTH; i++) {
        ss << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(hash[i]);
    }
    
    return ss.str();
}

// Function to generate pseudo-random positions based on hash
std::vector<PixelPosition> generatePseudoRandomPositions(const std::string& hashValue, int height, int width, int numBits) {
    // Convert hash to an integer seed
    unsigned long long seed = 0;
    std::istringstream iss(hashValue.substr(0, 16));
    iss >> std::hex >> seed;
    
    // Create a list of all interior pixel coordinates
    std::vector<PixelPosition> interiorPixels;
    for (int y = 1; y < height - 1; y++) {
        for (int x = 1; x < width - 1; x++) {
            interiorPixels.push_back({y, x});
        }
    }
    
    // Check if we have enough pixels
    int totalInteriorPixels = interiorPixels.size();
    if (totalInteriorPixels < numBits) {
        throw std::runtime_error("Image is too small for the message. Need at least " + 
                                std::to_string(numBits) + " interior pixels.");
    }
    
    // Shuffle based on the seed
    std::mt19937 gen(seed);
    std::shuffle(interiorPixels.begin(), interiorPixels.end(), gen);
    
    // Return needed positions
    return std::vector<PixelPosition>(interiorPixels.begin(), interiorPixels.begin() + numBits);
}

// Function to embed a message into an image
int embedMessage(const std::string& inputPath, const std::string& outputPath, const std::string& message) {
    // Load the image
    cv::Mat image = cv::imread(inputPath);
    if (image.empty()) {
        throw std::runtime_error("Could not open image at " + inputPath);
    }
    
    int height = image.rows;
    int width = image.cols;
    
    // Compute hash from border pixels
    std::string borderHash = computeBorderHash(image);
    
    // Convert message to bytes
    std::vector<unsigned char> messageBytes(message.begin(), message.end());
    int messageLength = messageBytes.size();
    
    // Ensure message length isn't too large
    if (messageLength > 65535) {
        throw std::runtime_error("Message too large - maximum size is 65535 bytes");
    }
    
    // Create a 2-byte header with the message length
    std::vector<unsigned char> lengthBytes = {
        static_cast<unsigned char>((messageLength >> 8) & 0xFF),  // High byte
        static_cast<unsigned char>(messageLength & 0xFF)          // Low byte
    };
    
    // Combine header and message
    std::vector<unsigned char> dataToHide;
    dataToHide.insert(dataToHide.end(), lengthBytes.begin(), lengthBytes.end());
    dataToHide.insert(dataToHide.end(), messageBytes.begin(), messageBytes.end());
    int totalBits = dataToHide.size() * 8;
    
    // Generate embedding positions
    std::vector<PixelPosition> positions = generatePseudoRandomPositions(borderHash, height, width, totalBits);
    
    // Allocate device memory
    unsigned char* d_image;
    PixelPosition* d_positions;
    unsigned char* d_data;
    
    // Flatten the image for GPU processing
    std::vector<unsigned char> flatImage;
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            cv::Vec3b pixel = image.at<cv::Vec3b>(y, x);
            flatImage.push_back(pixel[0]);  // B
            flatImage.push_back(pixel[1]);  // G
            flatImage.push_back(pixel[2]);  // R
        }
    }
    
    // Allocate and copy data to GPU
    cudaMalloc(&d_image, flatImage.size() * sizeof(unsigned char));
    cudaMalloc(&d_positions, positions.size() * sizeof(PixelPosition));
    cudaMalloc(&d_data, dataToHide.size() * sizeof(unsigned char));
    
    cudaMemcpy(d_image, flatImage.data(), flatImage.size() * sizeof(unsigned char), cudaMemcpyHostToDevice);
    cudaMemcpy(d_positions, positions.data(), positions.size() * sizeof(PixelPosition), cudaMemcpyHostToDevice);
    cudaMemcpy(d_data, dataToHide.data(), dataToHide.size() * sizeof(unsigned char), cudaMemcpyHostToDevice);
    
    // Define block and grid sizes
    int blockSize = 256;
    int gridSize = (totalBits + blockSize - 1) / blockSize;
    
    // Launch kernel
    embedBitsKernel<<<gridSize, blockSize>>>(d_image, width, height, d_positions, d_data, totalBits);
    
    // Copy the result back to host
    cudaMemcpy(flatImage.data(), d_image, flatImage.size() * sizeof(unsigned char), cudaMemcpyDeviceToHost);
    
    // Update the image with embedded data
    int idx = 0;
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            cv::Vec3b& pixel = image.at<cv::Vec3b>(y, x);
            pixel[0] = flatImage[idx++];  // B
            pixel[1] = flatImage[idx++];  // G
            pixel[2] = flatImage[idx++];  // R
        }
    }
    
    // Free GPU memory
    cudaFree(d_image);
    cudaFree(d_positions);
    cudaFree(d_data);
    
    // Save the watermarked image (ensuring PNG format)
    std::string finalOutputPath = outputPath;
    if (finalOutputPath.substr(finalOutputPath.find_last_of(".") + 1) != "png") {
        finalOutputPath = finalOutputPath.substr(0, finalOutputPath.find_last_of(".")) + ".png";
    }
    
    std::vector<int> compressionParams;
    compressionParams.push_back(cv::IMWRITE_PNG_COMPRESSION);
    compressionParams.push_back(0);  // 0 = no compression
    
    cv::imwrite(finalOutputPath, image, compressionParams);
    
    std::cout << "DEBUG: Embedded message length: " << messageLength << " bytes" << std::endl;
    return messageLength * 8;
}

// Function to extract a message from a watermarked image
std::string extractMessage(const std::string& inputPath) {
    // Load the watermarked image
    cv::Mat image = cv::imread(inputPath);
    if (image.empty()) {
        throw std::runtime_error("Could not open image at " + inputPath);
    }
    
    int height = image.rows;
    int width = image.cols;
    
    // Compute hash from border pixels
    std::string borderHash = computeBorderHash(image);
    
    // First extract the 2-byte header (16 bits)
    int headerBits = 16;
    std::vector<PixelPosition> headerPositions = generatePseudoRandomPositions(borderHash, height, width, headerBits);
    
    // Flatten the image for GPU processing
    std::vector<unsigned char> flatImage;
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            cv::Vec3b pixel = image.at<cv::Vec3b>(y, x);
            flatImage.push_back(pixel[0]);  // B
            flatImage.push_back(pixel[1]);  // G
            flatImage.push_back(pixel[2]);  // R
        }
    }
    
    // Allocate device memory
    unsigned char* d_image;
    PixelPosition* d_positions;
    unsigned char* d_bits;
    
    // Allocate and copy data to GPU
    cudaMalloc(&d_image, flatImage.size() * sizeof(unsigned char));
    cudaMalloc(&d_positions, headerPositions.size() * sizeof(PixelPosition));
    cudaMalloc(&d_bits, headerBits * sizeof(unsigned char));
    
    cudaMemcpy(d_image, flatImage.data(), flatImage.size() * sizeof(unsigned char), cudaMemcpyHostToDevice);
    cudaMemcpy(d_positions, headerPositions.data(), headerPositions.size() * sizeof(PixelPosition), cudaMemcpyHostToDevice);
    
    // Define block and grid sizes
    int blockSize = 256;
    int gridSize = (headerBits + blockSize - 1) / blockSize;
    
    // Launch kernel to extract header bits
    extractBitsKernel<<<gridSize, blockSize>>>(d_image, width, height, d_positions, d_bits, headerBits);
    
    // Copy the extracted bits back to host
    std::vector<unsigned char> headerBitsHost(headerBits);
    cudaMemcpy(headerBitsHost.data(), d_bits, headerBits * sizeof(unsigned char), cudaMemcpyDeviceToHost);
    
    // Convert bits to bytes (2 bytes for length)
    unsigned char lengthBytes[2] = {0, 0};
    for (int i = 0; i < 2; i++) {
        for (int j = 0; j < 8; j++) {
            // MSB first
            lengthBytes[i] = (lengthBytes[i] << 1) | headerBitsHost[i*8 + j];
        }
    }
    
    // Extract message length
    int messageLength = (lengthBytes[0] << 8) | lengthBytes[1];
    std::cout << "DEBUG: Detected message length: " << messageLength << " bytes" << std::endl;
    
    // Safety check
    if (messageLength > 65535 || messageLength <= 0) {
        return "Error: Invalid message length detected: " + std::to_string(messageLength);
    }
    
    // Generate positions for the full message
    int totalBits = headerBits + (messageLength * 8);
    std::vector<PixelPosition> allPositions = generatePseudoRandomPositions(borderHash, height, width, totalBits);
    
    // Only need positions for the message part
    std::vector<PixelPosition> messagePositions(allPositions.begin() + headerBits, allPositions.end());
    int messageBits = messageLength * 8;
    
    // Free previous GPU allocations
    cudaFree(d_positions);
    cudaFree(d_bits);
    
    // Allocate new memory for message extraction
    cudaMalloc(&d_positions, messagePositions.size() * sizeof(PixelPosition));
    cudaMalloc(&d_bits, messageBits * sizeof(unsigned char));
    
    cudaMemcpy(d_positions, messagePositions.data(), messagePositions.size() * sizeof(PixelPosition), cudaMemcpyHostToDevice);
    
    // Calculate new grid size for message bits
    gridSize = (messageBits + blockSize - 1) / blockSize;
    
    // Launch kernel to extract message bits
    extractBitsKernel<<<gridSize, blockSize>>>(d_image, width, height, d_positions, d_bits, messageBits);
    
    // Copy the extracted bits back to host
    std::vector<unsigned char> messageBitsHost(messageBits);
    cudaMemcpy(messageBitsHost.data(), d_bits, messageBits * sizeof(unsigned char), cudaMemcpyDeviceToHost);
    
    // Convert bits to bytes
    std::vector<unsigned char> messageBytes(messageLength);
    for (int i = 0; i < messageLength; i++) {
        unsigned char byte = 0;
        for (int j = 0; j < 8; j++) {
            // MSB first
            if (i*8 + j < messageBitsHost.size()) {
                byte = (byte << 1) | messageBitsHost[i*8 + j];
            }
        }
        messageBytes[i] = byte;
    }
    
    // Free GPU memory
    cudaFree(d_image);
    cudaFree(d_positions);
    cudaFree(d_bits);
    
    // Convert bytes to string
    try {
        std::string message(messageBytes.begin(), messageBytes.end());
        return message;
    } catch (const std::exception& e) {
        // If decoding fails, return hex representation
        std::stringstream hexData;
        for (size_t i = 0; i < std::min(messageBytes.size(), size_t(32)); i++) {
            hexData << std::hex << std::setw(2) << std::setfill('0') << static_cast<int>(messageBytes[i]);
        }
        return "Error: Could not decode message. First 32 bytes in hex: " + hexData.str() + "...";
    }
}