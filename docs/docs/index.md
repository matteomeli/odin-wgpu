# Introduction

## What is WebGPU?

WebGPU is a [specification](https://www.w3.org/TR/webgpu/), maintained by the [W3C Consortium](https://en.wikipedia.org/wiki/World_Wide_Web_Consortium), for an API that gives cross-platform efficient GPU access for the Web. This allows to carry out high-performance computation and draw complex images that can be rendered in the browser. WebGPU is intended to supersede WebGL to become standard for the Web. Multiple implementation exists in JavaScript, Rust, C++ and C with support for underlying "host" API such as Vulkan, Metal, and Direct3D 12. Javascript WebGPU can be provided in the browser or other environment like Node.js or Deno. Rust and C++ have their own implementation of the specification. Other languages, like Python, Java, Go and Odin, can use the native implementation in C.

## Why Odin?

[Odin](https://odin-lang.org/) is a programming language presented as a modern alternative to C to give back to developers the "joy of programming". I have been learning Odin and enjoying it thus far. I'll use Odin as a tool to show how to program with WebGPU, you are welcome to make your own opinion about it. Conveniently, Odin exposes bindings to WebGPU API in its `wgpu` vendor library. You should try to get a bit familiar with Odin [here](https://odin-lang.org/docs/overview/) before using this tutorial, as I won't go much in detail on Odin syntax. That said, I will try to explain and go in detail whenever necessary or interesting. You can follow these [instructions](https://odin-lang.org/docs/install/) to install Odin on your system, before starting to follow this tutorial.
