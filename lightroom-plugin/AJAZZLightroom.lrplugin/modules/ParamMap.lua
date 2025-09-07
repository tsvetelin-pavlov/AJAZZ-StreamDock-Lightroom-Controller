-- Map canonical IDs to LrDevelopController control names
-- IDs are used by StreamDock; values are strings expected by LrDevelopController
local M = {
  -- Basic
  Exposure2012 = 'Exposure',
  Contrast2012 = 'Contrast',
  Highlights2012 = 'Highlights',
  Shadows2012 = 'Shadows',
  Whites2012 = 'Whites',
  Blacks2012 = 'Blacks',
  Texture = 'Texture',
  Clarity2012 = 'Clarity',
  Dehaze = 'Dehaze',
  Vibrance = 'Vibrance',
  Saturation = 'Saturation',
  Temperature = 'Temperature',
  Temp = 'Temperature',
  Tint = 'Tint',

  -- Parametric Tone Curve
  ParametricHighlights = 'Parametric Highlights',
  ParametricLights = 'Parametric Lights',
  ParametricDarks = 'Parametric Darks',
  ParametricShadows = 'Parametric Shadows',

  -- Detail
  SharpeningAmount = 'Sharpening Amount',
  SharpeningRadius = 'Sharpening Radius',
  SharpeningDetail = 'Sharpening Detail',
  SharpeningMasking = 'Sharpening Masking',
  NoiseReductionLuminance = 'Luminance Smoothing',
  NoiseReductionLuminanceDetail = 'Luminance Detail',
  NoiseReductionLuminanceContrast = 'Luminance Contrast',
  NoiseReductionColor = 'Color Noise Reduction',
  NoiseReductionColorDetail = 'Color Detail',
  NoiseReductionColorSmoothness = 'Color Smoothness',

  -- Effects
  PostCropVignetteAmount = 'Post-Crop Vignetting Amount',
  PostCropVignetteMidpoint = 'Post-Crop Vignetting Midpoint',
  PostCropVignetteRoundness = 'Post-Crop Vignetting Roundness',
  PostCropVignetteFeather = 'Post-Crop Vignetting Feather',
  PostCropVignetteHighlights = 'Post-Crop Vignetting Highlights',
  GrainAmount = 'Grain Amount',
  GrainSize = 'Grain Size',
  GrainFrequency = 'Grain Frequency',

  -- Transform
  UprightYaw = 'Transform Yaw',
  UprightPitch = 'Transform Pitch',
  UprightRoll = 'Transform Roll',
  PerspectiveVertical = 'Transform Vertical',
  PerspectiveHorizontal = 'Transform Horizontal',
  PerspectiveRotate = 'Transform Rotate',
  AspectRatio = 'Transform Aspect',
  Scale = 'Transform Scale',
  XOffset = 'Transform X Offset',
  YOffset = 'Transform Y Offset',

  -- Calibration
  CalibrationShadowsTint = 'Shadows Tint',
  CalibrationRedPrimaryHue = 'Red Primary Hue',
  CalibrationRedPrimarySaturation = 'Red Primary Saturation',
  CalibrationGreenPrimaryHue = 'Green Primary Hue',
  CalibrationGreenPrimarySaturation = 'Green Primary Saturation',
  CalibrationBluePrimaryHue = 'Blue Primary Hue',
  CalibrationBluePrimarySaturation = 'Blue Primary Saturation',
}

return M
