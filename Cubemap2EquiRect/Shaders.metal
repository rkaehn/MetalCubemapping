
#include <metal_stdlib>

using namespace metal;

struct EquiRectVertex {
    float2 position;
    float2 texCoord;
};

typedef struct {
    float4 renderedCoordinate [[position]]; // clip space
    float2 position;
    float2 textureCoordinate;
    
} TextureMappingVertex;

// X from -1..+1, Y from -1..+1
// Projects provided vertices to corners of offscreen texture.
vertex TextureMappingVertex
projectTexture(unsigned int vertex_id  [[ vertex_id ]])
{
    // Triangle strip in NDC (normalized device coords).
    // The vertices' coord system has (0, 0) at the bottom left.
    float4x4 renderedCoordinates = float4x4(float4(-1.0, -1.0, 0.0, 1.0),
                                            float4( 1.0, -1.0, 0.0, 1.0),
                                            float4(-1.0,  1.0, 0.0, 1.0),
                                            float4( 1.0,  1.0, 0.0, 1.0));
    // The texture coord system has (0, 0) at the upper left
    // The s-axis is +ve right and the t-axis is +ve down
    float4x2 textureCoordinates = float4x2(float2(0.0, 1.0),
                                           float2(1.0, 1.0),
                                           float2(0.0, 0.0),
                                           float2(1.0, 0.0));
    TextureMappingVertex outVertex;
    outVertex.renderedCoordinate = renderedCoordinates[vertex_id];
    outVertex.position = outVertex.renderedCoordinate.xy;
    outVertex.textureCoordinate = textureCoordinates[vertex_id];
    return outVertex;
}

#define SRGB_ALPHA 0.055

float linear_from_srgb(float x)
{
    if (x <= 0.04045)
        return x / 12.92;
    else
        return powr((x + SRGB_ALPHA) / (1.0 + SRGB_ALPHA), 2.4);
}

float3 linear_from_srgb(float3 rgb)
{
    return float3(linear_from_srgb(rgb.r),
                  linear_from_srgb(rgb.g),
                  linear_from_srgb(rgb.b));
}

// Renders to a quad of dimensions 2x2
// The ranges for the x- and y-coords are [-1, 1]
// x = cos(φ)cos(θ), y = sin(φ), z = cos(φ)sin(θ)
// Note: the resolution of the output image has the dimensions of a square
// and equirectangular maps are 2:1 in resolution.
// The output of this fragment shader is to a 1:1 quad
fragment half4
outputEquiRectangularTexture(TextureMappingVertex  mappingVertex    [[stage_in]],
                             texturecube<half>          cubeMap     [[texture(0)]])
{
    constexpr sampler mapSampler(mip_filter::linear,
                                 mag_filter::linear,
                                 min_filter::linear);

    // u from -1..+1, v from -1..+1
    float2 uv = mappingVertex.position.xy;
    // Convert u, v to (θ, φ) angle
    float2 a = uv * float2(3.14159265, 1.57079633);   // π, π/2
    // θ = a.x,  φ = a.y
    // Range for θ = [-π, π] and Range for φ = [-π/2, π/2]
    // Convert to 3D Cartesian coordinates
    float2 c = cos(a);      // c.x = cos(θ) c.y = cos(φ)
    float2 s = sin(a);      // s.x = sin(θ) s.y = sin(φ)
    // May need to prepend a '-' sign to x-coordinate. Why???
    float3 direction = float3(c.y * c.x, s.y, c.y * s.x);
    half4 color = cubeMap.sample(mapSampler, direction);
/*
    float3 srgbColor = float3(color.rgb);
    srgbColor = linear_from_srgb(srgbColor);
    return half4(srgbColor.r, srgbColor.g, srgbColor.b, 1.0);
*/
    return color;
}

/*
 The dimensions of the quad passed is 4:2 units.
 */
vertex TextureMappingVertex
simpleVertexShader(unsigned int                 vertex_id       [[ vertex_id ]],
                   const device EquiRectVertex *vertices        [[ buffer(0) ]],
                   constant float2x2            &scaleMatrix    [[buffer(1)]])
{
    float2 position = vertices[vertex_id].position;
    TextureMappingVertex vert;
    // Scale the quad to 1:1 so that the entire 2D view is filled with
    // pixels from the texture. The 2D view is [-1, 1] x [-1, 1]
    vert.renderedCoordinate = float4(scaleMatrix * position, 0.0, 1.0);
    vert.textureCoordinate = vertices[vertex_id].texCoord;
    return vert;
}

fragment half4
simpleFragmentShader(TextureMappingVertex  mappingVertex    [[stage_in]],
               texture2d<half>          equiRectangularMap  [[texture(0)]])
{
    constexpr sampler mapSampler(s_address::clamp_to_edge,  // default
                                 t_address::clamp_to_edge,
                                 mip_filter::linear,
                                 mag_filter::linear,
                                 min_filter::linear);

    float2 uv = mappingVertex.textureCoordinate;
    half4 color = equiRectangularMap.sample(mapSampler, uv);

    return color;
}
