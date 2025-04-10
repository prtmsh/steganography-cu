#include <iostream>
#include <string>
#include <fstream>
#include <filesystem>
#include "watermark.h"

void printUsage(const std::string& programName) {
    std::cout << "Border-Hash Based Text Watermarking (CUDA Version)" << std::endl;
    std::cout << "Usage: " << programName << " --mode [embed|extract] [options]" << std::endl;
    std::cout << "Options:" << std::endl;
    std::cout << "  --mode embed|extract   Operation mode (required)" << std::endl;
    std::cout << "  --input PATH           Path to input image (required)" << std::endl;
    std::cout << "  --output PATH          Path to save output image (required for embed mode)" << std::endl;
    std::cout << "  --message TEXT         Text message to embed (required for embed mode)" << std::endl;
    std::cout << "  --help                 Show this help message" << std::endl;
}

int main(int argc, char* argv[]) {
    // Default values
    std::string mode;
    std::string inputPath;
    std::string outputPath;
    std::string message;
    
    // Parse command line arguments
    for (int i = 1; i < argc; i++) {
        std::string arg = argv[i];
        
        if (arg == "--help") {
            printUsage(argv[0]);
            return 0;
        } else if (arg == "--mode") {
            if (i + 1 < argc) {
                mode = argv[++i];
                if (mode != "embed" && mode != "extract") {
                    std::cerr << "Error: Mode must be either 'embed' or 'extract'" << std::endl;
                    return 1;
                }
            } else {
                std::cerr << "Error: --mode requires a value" << std::endl;
                return 1;
            }
        } else if (arg == "--input") {
            if (i + 1 < argc) {
                inputPath = argv[++i];
            } else {
                std::cerr << "Error: --input requires a path" << std::endl;
                return 1;
            }
        } else if (arg == "--output") {
            if (i + 1 < argc) {
                outputPath = argv[++i];
            } else {
                std::cerr << "Error: --output requires a path" << std::endl;
                return 1;
            }
        } else if (arg == "--message") {
            if (i + 1 < argc) {
                message = argv[++i];
            } else {
                std::cerr << "Error: --message requires text" << std::endl;
                return 1;
            }
        } else {
            std::cerr << "Error: Unknown option: " << arg << std::endl;
            printUsage(argv[0]);
            return 1;
        }
    }
    
    // Validate required arguments
    if (mode.empty()) {
        std::cerr << "Error: --mode is required" << std::endl;
        printUsage(argv[0]);
        return 1;
    }
    
    if (inputPath.empty()) {
        std::cerr << "Error: --input is required" << std::endl;
        printUsage(argv[0]);
        return 1;
    }
    
    if (mode == "embed") {
        if (outputPath.empty()) {
            std::cerr << "Error: --output is required for embed mode" << std::endl;
            return 1;
        }
        if (message.empty()) {
            std::cerr << "Error: --message is required for embed mode" << std::endl;
            return 1;
        }
    }
    
    // Check if input file exists
    if (!std::filesystem::exists(inputPath)) {
        std::cerr << "Error: Input file '" << inputPath << "' does not exist" << std::endl;
        return 1;
    }
    
    try {
        if (mode == "embed") {
            int bitsEmbedded = embedMessage(inputPath, outputPath, message);
            std::cout << "Success: Message embedded into '" << outputPath << "'" << std::endl;
            std::cout << "Message length: " << message.length() << " characters (" << bitsEmbedded << " bits)" << std::endl;
        } else if (mode == "extract") {
            std::string extractedMessage = extractMessage(inputPath);
            std::cout << "Extracted message: " << extractedMessage << std::endl;
        }
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << std::endl;
        return 1;
    }
    
    return 0;
}