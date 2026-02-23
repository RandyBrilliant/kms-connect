"""
Test script for OCR functionality.
Run this to verify Google Cloud Vision OCR is working correctly.
"""
import os
import sys
import django

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from django.conf import settings


def test_ocr_setup():
    """Test OCR configuration and dependencies."""
    print("\n" + "="*60)
    print("KMS-Connect OCR Setup Test")
    print("="*60 + "\n")
    
    # Test 1: Check Google Cloud Vision import
    print("Test 1: Google Cloud Vision Library")
    print("-" * 40)
    try:
        from google.cloud import vision
        print("✓ Google Cloud Vision library is installed")
        print(f"  Location: {vision.__file__}")
    except ImportError as e:
        print(f"✗ Google Cloud Vision library NOT installed")
        print(f"  Error: {e}")
        print("  Fix: Run 'pip install google-cloud-vision==3.12.1'")
        return False
    
    # Test 2: Check credentials configuration
    print("\nTest 2: Credentials Configuration")
    print("-" * 40)
    credentials_path = settings.GOOGLE_APPLICATION_CREDENTIALS
    if credentials_path:
        print(f"✓ GOOGLE_APPLICATION_CREDENTIALS is set")
        print(f"  Path: {credentials_path}")
        
        if os.path.exists(credentials_path):
            print(f"✓ Credentials file exists")
            file_size = os.path.getsize(credentials_path)
            print(f"  Size: {file_size} bytes")
        else:
            print(f"✗ Credentials file NOT found at path")
            print(f"  Please create the file or update the path in .env")
            return False
    else:
        print("✗ GOOGLE_APPLICATION_CREDENTIALS is not set")
        print("  Fix: Set GOOGLE_APPLICATION_CREDENTIALS in .env")
        return False
    
    # Test 3: Check environment variable
    print("\nTest 3: Environment Variable")
    print("-" * 40)
    env_creds = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if env_creds:
        print(f"✓ GOOGLE_APPLICATION_CREDENTIALS environment variable is set")
        print(f"  Value: {env_creds}")
    else:
        print("⚠ GOOGLE_APPLICATION_CREDENTIALS environment variable not set")
        print("  This is set automatically by settings.py")
    
    # Test 4: Test Vision API client initialization
    print("\nTest 4: Vision API Client")
    print("-" * 40)
    try:
        client = vision.ImageAnnotatorClient()
        print("✓ Vision API client initialized successfully")
        print("  Ready to process images")
    except Exception as e:
        print(f"✗ Failed to initialize Vision API client")
        print(f"  Error: {e}")
        print("  Check your credentials file is valid JSON")
        return False
    
    # Test 5: Check OCR functions
    print("\nTest 5: OCR Functions")
    print("-" * 40)
    try:
        from account.ocr import extract_text_from_image, parse_ktp_text
        print("✓ extract_text_from_image function available")
        print("✓ parse_ktp_text function available")
    except ImportError as e:
        print(f"✗ Failed to import OCR functions")
        print(f"  Error: {e}")
        return False
    
    # Summary
    print("\n" + "="*60)
    print("✓ All OCR tests passed!")
    print("="*60)
    print("\nOCR is properly configured and ready to use.")
    print("\nNext steps:")
    print("1. Restart your Django development server")
    print("2. Test the OCR preview endpoint from your mobile app")
    print("3. Upload a KTP image and click 'Ekstrak Data dari KTP'")
    print("\n")
    return True


if __name__ == "__main__":
    try:
        success = test_ocr_setup()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"\n✗ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
