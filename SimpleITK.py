
# Minimal pure-Python SimpleITK stub (lightweight)
# WARNING: This is NOT the real SimpleITK. Only for placeholder use.

class Image:
    def __init__(self, array):
        self.array = array

def ReadImage(path):
    raise NotImplementedError("This lightweight SimpleITK.py cannot read medical images. Please replace with full SimpleITK if needed.")

def GetArrayFromImage(img):
    return img.array

def WriteImage(img, path):
    raise NotImplementedError("WriteImage not implemented in lightweight SimpleITK.py")

def SmoothingRecursiveGaussian(img, sigma):
    raise NotImplementedError("Filters not implemented in lightweight SimpleITK.py")

def Median(img):
    raise NotImplementedError("Median filter not implemented.")

__all__ = [
    "Image",
    "ReadImage",
    "GetArrayFromImage",
    "WriteImage",
    "SmoothingRecursiveGaussian",
    "Median",
]
