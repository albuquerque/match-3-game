# Achievement Page Background Image Guide

## Overview

The achievements page now supports custom background images with automatic fallback to solid biblical-themed colors. This enhances the spiritual atmosphere while maintaining excellent readability.

## 🎨 Background Image Support

### Automatic Detection

The system automatically searches for background images in these paths (in priority order):

**Primary Locations:**
- `res://textures/backgrounds/achievements_bg.jpg`
- `res://textures/backgrounds/achievements_bg.png`
- `res://textures/backgrounds/parchment_bg.jpg` 
- `res://textures/backgrounds/parchment_bg.png`

**Alternative Locations:**
- `res://textures/backgrounds/scroll_bg.jpg`
- `res://textures/backgrounds/scroll_bg.png`
- `res://textures/achievement_background.jpg`
- `res://textures/achievement_background.png`
- `res://textures/biblical_background.jpg`
- `res://textures/biblical_background.png`

### Recommended Image Specifications

**For optimal biblical theme:**
- **Resolution**: 1920x1080 or higher (supports various aspect ratios)
- **Format**: JPG (smaller file size) or PNG (transparency support)
- **Content**: Biblical scenes, parchment textures, ancient scrolls, heavenly landscapes
- **Color Palette**: Warm earth tones, golds, creams, soft blues
- **Style**: Subtle, non-distracting backgrounds that don't interfere with text

### Image Suggestions

**Biblical Theme Ideas:**
- **Ancient Parchment**: Aged paper texture with subtle staining
- **Scroll Background**: Rolled manuscript with Hebrew/Greek text shadows
- **Heavenly Scene**: Soft clouds with golden light rays
- **Jerusalem Landscape**: Ancient city views with warm lighting
- **Temple Interior**: Columns and arches with sacred atmosphere
- **Garden Scene**: Eden-inspired peaceful nature backgrounds

## 🔧 Technical Implementation

### Automatic System

The page automatically:
1. **Searches** for images in predefined paths
2. **Loads** the first available image
3. **Scales** to fill the screen while maintaining aspect ratio
4. **Applies** semi-transparent overlay for text readability
5. **Falls back** to solid parchment color if no image found

### Manual Background Setting

You can programmatically set a custom background:

```gdscript
# In your code
var achievements_page = load("res://scripts/AchievementsPage.gd").new()
achievements_page.set_background_image("res://textures/my_custom_bg.jpg")
```

### Overlay System

**Automatic Overlay:**
- Semi-transparent parchment color (`Color(0.96, 0.94, 0.88, 0.7)`)
- Ensures text remains readable over any background
- Maintains biblical theme consistency

## 📁 File Organization

**Recommended folder structure:**
```
textures/
├── backgrounds/
│   ├── achievements_bg.jpg          # Primary achievement background
│   ├── parchment_bg.jpg            # Fallback parchment texture
│   └── scroll_bg.jpg               # Alternative scroll texture
├── achievement_background.jpg       # Legacy location support
└── biblical_background.jpg         # General biblical theme
```

## 🎨 Design Guidelines

### Color Harmony
- **Warm earth tones**: Browns, golds, creams match biblical panels
- **Soft blues**: Complement the incomplete achievement colors
- **Avoid harsh contrasts**: Keep backgrounds subtle and peaceful

### Content Guidelines
- **Appropriate imagery**: Biblical scenes, nature, ancient texts
- **Non-distracting**: Background should enhance, not compete with UI
- **Cultural sensitivity**: Respectful representation of sacred themes
- **Family-friendly**: Suitable for all ages

### Technical Quality
- **High resolution**: Crisp on all device sizes
- **Optimized file size**: Balance quality with loading speed
- **Consistent style**: Match the overall game's biblical aesthetic

## 📖 Biblical Theme Inspiration

### Scripture-Inspired Backgrounds
- **Psalm 23**: Green pastures and still waters
- **Genesis Creation**: Light breaking through darkness
- **Temple Imagery**: Sacred spaces with golden light
- **Ancient Scrolls**: Manuscript textures with subtle text
- **Heavenly Scenes**: Clouds, light rays, peaceful skies

### Color Psychology
- **Gold**: Divine light, heavenly glory, achievement completion
- **Cream/Parchment**: Ancient wisdom, sacred texts, timelessness
- **Soft Blue**: Peace, hope, heaven, spiritual tranquility
- **Earth Browns**: Stability, grounding, human connection to divine

## 🚀 Usage Examples

### Adding Your Background Image

1. **Create your biblical-themed background** (1920x1080 recommended)
2. **Save as JPG/PNG** in `textures/backgrounds/achievements_bg.jpg`
3. **Launch the game** - background loads automatically
4. **Test readability** - ensure text is clearly visible

### Creating Parchment Texture

For a simple parchment background:
1. Start with cream/beige base color
2. Add subtle texture and aging effects  
3. Include light brown staining around edges
4. Keep center area lighter for text readability
5. Save as `parchment_bg.jpg`

### Multiple Theme Support

You can provide multiple backgrounds:
- `achievements_bg.jpg` - Primary detailed background
- `parchment_bg.jpg` - Simple parchment fallback  
- `scroll_bg.jpg` - Alternative scroll design

The system will use the first available image.

## ✅ Benefits

- **Enhanced Atmosphere**: Rich biblical theme immersion
- **Automatic Fallback**: Always works even without images
- **Readable Text**: Overlay ensures UI remains functional
- **Flexible**: Supports various image formats and locations
- **Performance**: Efficient loading and scaling

## 🔄 Future Enhancements

Potential future features:
- **Multiple backgrounds**: Random selection for variety
- **Seasonal themes**: Christmas, Easter, harvest backgrounds
- **Achievement-specific**: Different backgrounds per category
- **Animation support**: Subtle animated backgrounds
- **User selection**: Let players choose their preferred background

---

The background image system transforms the achievements page into a visually rich, spiritually inspiring experience while maintaining the excellent functionality and readability of the achievement tracking system.
