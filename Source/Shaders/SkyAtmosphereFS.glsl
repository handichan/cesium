/**
 * @license
 * Copyright (c) 2000-2005, Sean O'Neil (s_p_oneil@hotmail.com)
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 
 * * Redistributions of source code must retain the above copyright notice,
 *   this list of conditions and the following disclaimer.
 * * Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 * * Neither the name of the project nor the names of its contributors may be
 *   used to endorse or promote products derived from this software without
 *   specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * Modifications made by Analytical Graphics, Inc.
 */
 
 // Code:  http://sponeil.net/
 // GPU Gems 2 Article:  http://http.developer.nvidia.com/GPUGems2/gpugems2_chapter16.html
 // HSV <-> RGB conversion with minimal branching: http://lolengine.net/blog/2013/07/27/rgb-to-hsv-in-glsl

uniform vec3 u_hsvShift; // hue, saturation, value

const float g = -0.95;
const float g2 = g * g;
const float epsilon = 1.0e-10;
const vec4 K_RGB2HSB = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
const vec4 K_HSB2RGB = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);


varying vec3 v_rayleighColor;
varying vec3 v_mieColor;
varying vec3 v_toCamera;
varying vec3 v_positionEC;

vec3 rgb2hsb(vec3 rgbColor)
{
    vec4 p = mix(vec4(rgbColor.bg, K_RGB2HSB.wz), vec4(rgbColor.gb, K_RGB2HSB.xy), step(rgbColor.b, rgbColor.g));
    vec4 q = mix(vec4(p.xyw, rgbColor.r), vec4(rgbColor.r, p.yzx), step(p.x, rgbColor.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsb2rgb(vec3 hsbColor)
{
    vec3 p = abs(fract(hsbColor.xxx + K_HSB2RGB.xyz) * 6.0 - K_HSB2RGB.www);
    return hsbColor.z * mix(K_HSB2RGB.xxx, clamp(p - K_HSB2RGB.xxx, 0.0, 1.0), hsbColor.y);
}

void main (void)
{
    // Extra normalize added for Android
    float cosAngle = dot(czm_sunDirectionWC, normalize(v_toCamera)) / length(v_toCamera);
    float rayleighPhase = 0.75 * (1.0 + cosAngle * cosAngle);
    float miePhase = 1.5 * ((1.0 - g2) / (2.0 + g2)) * (1.0 + cosAngle * cosAngle) / pow(1.0 + g2 - 2.0 * g * cosAngle, 1.5);
    
    const float exposure = 2.0;
    
    vec3 rgb = rayleighPhase * v_rayleighColor + miePhase * v_mieColor;
    rgb = vec3(1.0) - exp(-exposure * rgb);

    // convert rgb color to hsv
    vec3 hsv = rgb2hsb(rgb);
    // perform hsv shift
    hsv.x += u_hsvShift.x; // hue
    hsv.y = clamp(hsv.y + u_hsvShift.y, 0.0, 1.0); // saturation
    hsv.z += u_hsvShift.z; // brightness
    // convert shifted hsv back to rgb
    rgb = hsb2rgb(hsv);

    float l = czm_luminance(rgb);
    gl_FragColor = vec4(rgb, min(smoothstep(0.0, 0.1, l), 1.0) * smoothstep(0.0, 1.0, czm_morphTime));
}
