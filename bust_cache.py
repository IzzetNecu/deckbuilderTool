import os
import re
import time

def add_cache_buster():
    timestamp = str(int(time.time()))
    src_dir = 'src'
    
    # Regex to find ES module imports of local files
    import_pattern = re.compile(r'(from\s+["\']\..+?\.js)(\?v=\d+)?(["\'])')
    dynamic_import_pattern = re.compile(r'(import\s*\(\s*["\']\..+?\.js)(\?v=\d+)?(["\']\s*\))')
    
    for root, _, files in os.walk(src_dir):
        for file in files:
            if file.endswith('.js'):
                path = os.path.join(root, file)
                with open(path, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Replace standard imports
                new_content = import_pattern.sub(rf'\g<1>?v={timestamp}\g<3>', content)
                # Replace dynamic imports
                new_content = dynamic_import_pattern.sub(rf'\g<1>?v={timestamp}\g<3>', new_content)
                
                if new_content != content:
                    with open(path, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f"Updated imports in {path}")
                    
    # Also update index.html
    index_path = 'index.html'
    if os.path.exists(index_path):
        with open(index_path, 'r', encoding='utf-8') as f:
            content = f.read()
        script_pattern = re.compile(r'(src=["\'].+?\.js)(\?v=\d+)?(["\'])')
        new_content = script_pattern.sub(rf'\g<1>?v={timestamp}\g<3>', content)
        if new_content != content:
            with open(index_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Updated script tags in {index_path}")

if __name__ == '__main__':
    add_cache_buster()
