# Digital Humans for Godot Engine

This project aims at providing shaders and materials for creating realistic
looking characters in games made with Godot Engine 4. It can serve as a learning
resource, but it is equally suited to be used directly in games.

The project is licensed under the MIT license, all art assets are CC0 except
where noted differently in the [Credits](#credits) section.

## What's in the Box?

- [An eye shader & model](#eye-shader) with iris refraction and tons of configurable parameters

## Eye Shader

Eye shaders in the past often required the models to have the iris cavity modeled
out and used multiple materials to create the effect of depth and refraction. This
shader works on a single mesh, refraction and depth are created entirely in the
shader and can be controlled by shader parameters.

For this setup to work, the mesh should be unwrapped in a certain way. The front
half of the mesh should be projected onto the UV plane with the center of the iris
in the center of the plane. The back half of the eye can be projected the same way
or be scaled down and pushed into one of the corners, it doesn't really matter. Up
in UV space should match Up in model space.

The project contains an eye model that can be exported, studied, and used any way
you like.

Features of this shader include:

- [X] Iris refraction and depth
- [ ] Configurable iris colors
- [X] A set of textures for various iris patterns
- [X] Configurable limbus width and darkness
- [X] Pupil diameter, width, and height are separately configurable
- [X] Parallax occlusion mapping
- [X] Subsurface scattering
- [ ] Iris caustics
