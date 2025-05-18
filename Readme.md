# Erosion Simulator

A Godot 4 project for simulating terrain erosion using compute shaders.  
This project generates procedural terrain with noise and applies hydraulic erosion in real time.  
It features an interactive UI for tweaking parameters and visualizing erosion effects.

## Features

- Procedural terrain generation using FastNoiseLite
- Hydraulic erosion simulation accelerated with compute shaders
- Erosion heatmap visualization (see where erosion and deposition occur)
- UI for adjusting noise and erosion parameters
- Export heightmaps as PNG images
- Animation of the erosion process

## Planned Features

- **Thermal erosion** (simulating landslides and slope-based material movement)
- **Wind erosion** (simulating sand/dust transport by wind)
- More erosion types and visualization options

## Why?

I made this project to learn Godot 4 and experiment with compute shaders for real-time terrain simulation.  
It’s open source—feel free to use, modify, or contribute!

## Getting Started

1. Clone or download this repository.
2. Open the project in [Godot 4](https://godotengine.org/).
3. Run the main scene to start experimenting.

## License

MIT License (see [LICENSE](LICENSE) for details).