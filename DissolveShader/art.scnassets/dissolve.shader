#pragma arguments

float dissolveStage;
float noiseScale;
texture2d<float, access::sample> noiseTexture;

#pragma transparent
#pragma body

const float edgeWidth = 0.03;
const float3 innerColor = float3(0.9, 0.15, 0);
const float3 outerColor = float3(0.0, 0.0, 0.0);

constexpr sampler noiseSampler(filter::linear, address::repeat);
float2 noiseCoords = noiseScale * _surface.ambientTexcoord;
float noiseValue = noiseTexture.sample(noiseSampler, noiseCoords).r;

if (noiseValue > dissolveStage) {
    discard_fragment();
}

float edgeDist = dissolveStage - noiseValue;
if (edgeDist < edgeWidth) {
    float t = edgeDist / edgeWidth;
    _output.color.rgb = mix(outerColor, innerColor, t);
}
