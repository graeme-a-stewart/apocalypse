# Fractal Spirals

These are curves formed from the iterative sequence:

1. Start at $(x, y) = (0, 0)$ with $n=0$ and $\theta = 0$
2. Calculate the angle $\theta_n = \theta_{n-1} + 2\pi s n$, where $s$ is irrational (i.e., each iteration increases the rotation by an additional $2\pi s$)
3. Move along the vector $(\cos \theta_n, sin \theta_n)$
4. Add 1 to $n$ and go back to step 2

These are described in Chapter 21, *The Fractal Golden Curlicue is Cool*.
