# Advanced Mechanics Assets

This document lists the assets needed for the advanced game mechanics implementation.

## Collectibles

### Coin
- **File**: `textures/{legacy,modern}/collectible_coin.png`
- **Size**: 64x64 pixels
- **Description**: Gold coin sprite for collectible items
- **Status**: Using existing `coin.svg` as fallback

### Gem
- **File**: `textures/{legacy,modern}/collectible_gem.png`
- **Size**: 64x64 pixels
- **Description**: Blue gem sprite for collectible items
- **Status**: Using existing `gem.svg` as fallback

### Artifact
- **File**: `textures/{legacy,modern}/collectible_artifact.png`
- **Size**: 64x64 pixels
- **Description**: Ancient artifact sprite for collectible items
- **Status**: Needs creation

## Obstacles

### Soft Crate
- **File**: `textures/{legacy,modern}/obstacle_crate_soft.png`
- **Size**: 64x64 pixels
- **Description**: Wooden crate that breaks in 1 hit
- **Status**: Needs creation

### Hard Crate
- **File**: `textures/{legacy,modern}/obstacle_crate_hard.png`
- **Size**: 64x64 pixels
- **Description**: Metal crate that requires multiple hits
- **States**: Intact, damaged (show progression)
- **Status**: Needs creation

### Rock
- **File**: `textures/{legacy,modern}/obstacle_rock.png`
- **Size**: 64x64 pixels
- **Description**: Rock obstacle that requires 3 hits
- **States**: Intact, cracked, very cracked
- **Status**: Needs creation

### Ice
- **File**: `textures/{legacy,modern}/obstacle_ice.png`
- **Size**: 64x64 pixels
- **Description**: Ice block obstacle
- **States**: Frozen, melting
- **Status**: Needs creation

### Chained Block
- **File**: `textures/{legacy,modern}/obstacle_chained.png`
- **Size**: 64x64 pixels
- **Description**: Block attached to a chain
- **Additional**: Chain/rope sprites needed
- **Status**: Needs creation

## Transformables

### Flower - Bud
- **File**: `textures/{legacy,modern}/transformable_flower_bud.png`
- **Size**: 64x64 pixels
- **Description**: Flower in bud state
- **Status**: Needs creation

### Flower - Bloom
- **File**: `textures/{legacy,modern}/transformable_flower_bloom.png`
- **Size**: 64x64 pixels
- **Description**: Bloomed flower
- **Status**: Needs creation

### Light Bulb - Off
- **File**: `textures/{legacy,modern}/transformable_lightbulb_off.png`
- **Size**: 64x64 pixels
- **Description**: Light bulb in off state
- **Status**: Needs creation

### Light Bulb - On
- **File**: `textures/{legacy,modern}/transformable_lightbulb_on.png`
- **Size**: 64x64 pixels
- **Description**: Light bulb in on state
- **Status**: Needs creation

### Egg - Whole
- **File**: `textures/{legacy,modern}/transformable_egg_whole.png`
- **Size**: 64x64 pixels
- **Description**: Intact egg
- **Status**: Needs creation

### Egg - Cracked
- **File**: `textures/{legacy,modern}/transformable_egg_cracked.png`
- **Size**: 64x64 pixels
- **Description**: Egg with cracks
- **Status**: Needs creation

### Egg - Hatched
- **File**: `textures/{legacy,modern}/transformable_egg_hatched.png`
- **Size**: 64x64 pixels
- **Description**: Hatched egg with creature
- **Status**: Needs creation

## Particle Effects

### Collection Sparkle
- **Description**: Particle effect when collecting items
- **Status**: Needs creation

### Obstacle Break
- **Description**: Particle effect when obstacle is destroyed
- **Status**: Needs creation

### Transformation Glow
- **Description**: Glow/sparkle effect during transformation
- **Status**: Needs creation

## Implementation Notes

1. **Fallback Visuals**: All mechanics classes have fallback visual creation using colored sprites if textures are not found.
2. **Both Themes**: Assets should be created for both "legacy" and "modern" themes.
3. **Consistency**: Keep art style consistent with existing tile graphics.
4. **Testing**: The mechanics work without textures using colored placeholders.

## Priority

**High Priority** (needed for basic functionality):
- Collectible coin (using existing coin.svg)
- Obstacle crate_soft
- Obstacle rock

**Medium Priority** (enhance gameplay):
- Transformable flower (bud/bloom)
- Collection particle effects

**Low Priority** (future expansion):
- All other variants
- Advanced particle effects
