import os

def combine_files(project_path, output_filename):
    allowed_extensions = ['.dart', '.yaml']
    ignore_folders = ['.git', '.dart_tool', 'build', 'android', 'ios', 'web', 'windows', 'macos', 'linux']

    with open(output_filename, 'w', encoding='utf-8') as outfile:
        for root, dirs, files in os.walk(project_path):
            dirs[:] = [d for d in dirs if d not in ignore_folders]
            
            for file in files:
                if any(file.endswith(ext) for ext in allowed_extensions):
                    file_path = os.path.join(root, file)
                    
                    outfile.write(f"\n\n{'='*60}\n")
                    outfile.write(f"File: {file_path}\n")
                    outfile.write(f"{'='*60}\n\n")
                    
                    try:
                        with open(file_path, 'r', encoding='utf-8') as infile:
                            outfile.write(infile.read())
                    except Exception as e:
                        outfile.write(f"Error reading file: {e}\n")

if __name__ == '__main__':
    current_directory = "."
    output_file = "combined_code.txt"
    combine_files(current_directory, output_file)
    print(f"Data save ho gaya hai: {output_file} mein!")