import pytesseract
from PIL import Image
import sys

try:
    img_path = r'C:/Users/ahmed/.gemini/antigravity/brain/09dc8fe8-c56c-40e5-a977-6574b5eec5b0/media__1774071569971.png'
    img = Image.open(img_path)
    text = pytesseract.image_to_string(img)
    print("OCR TEXT:")
    print(text)
except Exception as e:
    print(f"Error: {e}")
