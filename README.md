
# steganography-cu

**steganography-cu** is a CUDA-accelerated project that implements an invisible text watermarking scheme based on a border-hash method. It embeds text messages into images by encoding bits into the least significant bit (LSB) of the blue channel of selected interior pixels. The project leverages CUDA for accelerated processing and OpenCV for image manipulation, making it suitable for handling larger images and intensive watermarking tasks.

---

## How It Works

### Watermark Embedding

1. **Border Extraction & Hashing:**  
   The outermost 1-pixel-wide border of the image is used to compute a SHA-256 hash using OpenSSL. This ensures a unique and reproducible seed for each image.

2. **Pseudo-Random Pixel Selection:**  
   The resulting hash seeds a pseudo-random number generator (Mersenne Twister) that shuffles the interior pixel positions. This deterministically selects pixels based on the image's unique border hash.

3. **Message Encoding:**  
   The text message is converted into bytes using UTF-8 encoding. A 16-bit header encoding the message length (in bytes) is prepended to the message data.

4. **CUDA-Accelerated Embedding:**  
   A CUDA kernel embeds each bit of the header and message into the LSB of the blue channel of the selected interior pixels. The CUDA processing provides significant speed improvements for large images.

### Message Extraction

1. **Recomputing the Border Hash:**  
   The same SHA-256 hash is computed from the image’s border to re-seed the pseudo-random number generator.

2. **Reproducing Pixel Order:**  
   With the identical hash seed, the same pseudo-random sequence of interior pixel positions is generated.

3. **Header & Message Recovery:**  
   - The first 16 bits (header) are extracted to determine the message length.
   - The remaining bits are extracted and then reassembled back into the original text message.

---

## Project Structure

```
steganography-cu/
├── CMakeLists.txt        # CMake build configuration for CUDA & C++ project
├── main.cpp              # Main executable for embedding/extraction operations
├── watermark.cu          # CUDA kernels and functions for watermarking process
└── watermark.h           # Header file with function prototypes
```

---

## Features

- **CUDA Acceleration:**  
  Significantly speeds up the embedding and extraction of watermarks using GPU parallel processing.

- **Deterministic Embedding:**  
  Uses a SHA-256 hash of the image border to ensure a consistent pseudo-random pixel selection across embedding and extraction.

- **Robust Message Encoding:**  
  Supports text messages of up to 65,535 bytes (~65KB) through a 16-bit length header.

- **PNG Format Enforcement:**  
  Forces output images to be in PNG format to avoid compression artifacts and ensure watermark integrity.

- **Detailed Debug Information:**  
  Outputs debug messages (e.g., message length) during the embedding and extraction processes for troubleshooting.

---

## Requirements

- **CUDA-capable GPU** and the CUDA Toolkit installed.
- **C++17** compatible compiler.
- **OpenCV** – for image file handling and processing.
- **OpenSSL** – for SHA-256 hashing.
- **CMake (>=3.10)** – for configuring and building the project.

---

## Installation and Build Instructions

1. **Clone the Repository:**

   ```bash
   git clone https://github.com/prtmsh/steganography-cu.git
   cd steganography-cu
   ```

2. **Build the Project Using CMake:**

   Create a build directory and compile the project:
   
   ```bash
   mkdir build
   cd build
   cmake ..
   make
   ```

   This will compile the project and produce an executable named `watermark` in the `build` directory.

---

## Usage

### Embedding a Message

To embed a secret message into an image, run the executable with the `embed` mode:

```bash
./watermark --mode embed --input ../examples/input.jpg --output ../examples/watermarked.png --message "Your secret message"
```

> **Note:** The output image will be saved in PNG format even if another format is specified.

### Extracting a Message

To extract a watermark (i.e., retrieve the hidden text) from an image, use the `extract` mode:

```bash
./watermark --mode extract --input ../examples/watermarked.png
```

The extracted message will be printed to the console.

---

## Implementation Details

- **CUDA Kernels:**  
  - `embedBitsKernel`: Embeds individual bits into the LSB of the blue channel.
  - `extractBitsKernel`: Recovers the bits stored in the blue channel.

- **Border Hash Generation:**  
  The hash is computed by reading the pixels of the image's outer border. This hash guarantees that the pseudo-random pixel selection is both unique and reproducible.

- **Pseudo-Random Positions:**  
  After converting the hash to a seed, a list of all interior pixels (excluding the border) is shuffled using a Mersenne Twister. A subset of these pixels corresponding to the total number of bits (header + message) is then selected.

- **Error and Safety Checks:**  
  - Validates if the input image is large enough to embed the provided message.
  - Automatically converts output filenames to PNG to preserve quality.
  - Provides debug information during execution to help troubleshoot any issues.

---

## Limitations

- **Message Size:**  
  The maximum message size is limited to 65,535 bytes. Ensure your image has enough interior pixels to accommodate the message.

- **Image Integrity:**  
  The watermark relies on the unchanged border of the image. Any modifications (resizing, recompression, etc.) may prevent proper extraction.

- **Lossy Formats:**  
  JPEG or other lossy compression formats can corrupt the watermark. Always use PNG for watermarking tasks.

---

## Troubleshooting

- **Extraction Failures:**  
  If the watermark cannot be extracted, ensure that you are using the exact watermarked image with no modifications (e.g., cropping, recompression).

- **Debug Information:**  
  Look at the console debug messages (e.g., message length details) to gain insights into where the process might be failing.

- **CUDA Issues:**  
  Confirm that your GPU supports CUDA and that your CUDA toolkit is properly installed if you encounter GPU-related errors.

---