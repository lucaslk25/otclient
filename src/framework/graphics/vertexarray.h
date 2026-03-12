/*
 * Copyright (c) 2010-2026 OTClient <https://github.com/edubart/otclient>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#pragma once

#include "declarations.h"
#include <cmath>

class VertexArray
{
public:
    VertexArray(const size_t size = 64) { m_buffer.reserve(size); }

    ~VertexArray() = default;

    void addTriangle(const Point& a, const Point& b, const Point& c)
    {
        int arr[] = {
            a.x, a.y,
            b.x, b.y,
            c.x, c.y
        };

        const size_t size = sizeof(arr) / sizeof(int);
        m_buffer.insert(m_buffer.end(), &arr[0], &arr[size]);
    }

    void addRect(const Rect& rect)
    {
        const float top = rect.top();
        const float right = rect.right() + 1;
        const float bottom = rect.bottom() + 1;
        const float left = rect.left();

        float arr[] = {
            left, top,
            right, top,
            left, bottom,
            left, bottom,
            right, top,
            right, bottom
        };

        const size_t size = sizeof(arr) / sizeof(float);
        m_buffer.insert(m_buffer.end(), &arr[0], &arr[size]);
    }

    void addRect(const RectF& rect)
    {
        const float top = rect.top();
        const float right = rect.right() + 1.f;
        const float bottom = rect.bottom() + 1.f;
        const float left = rect.left();

        float arr[] = {
            left, top,
            right, top,
            left, bottom,
            left, bottom,
            right, top,
            right, bottom
        };

        const size_t size = sizeof(arr) / sizeof(float);
        m_buffer.insert(m_buffer.end(), &arr[0], &arr[size]);
    }

    void addQuad(const Rect& rect)
    {
        const float top = rect.top();
        const float right = rect.right() + 1;
        const float bottom = rect.bottom() + 1;
        const float left = rect.left();

        float arr[] = {
            left, top,
            right, top,
            left, bottom,
            left, bottom,
            right, top,
            right, bottom
        };

        const size_t size = sizeof(arr) / sizeof(float);
        m_buffer.insert(m_buffer.end(), &arr[0], &arr[size]);
    }


    void addHorizontallyFlippedQuad(const Rect& rect)
    {
        const float top = rect.top();
        const float right = rect.right() + 1;
        const float bottom = rect.bottom() + 1;
        const float left = rect.left();

        // Inverte left e right para flip horizontal
        float arr[] = {
            right, top,
            left, top,
            right, bottom,
            right, bottom,
            left, top,
            left, bottom
        };

        const size_t size = sizeof(arr) / sizeof(float);
        m_buffer.insert(m_buffer.end(), &arr[0], &arr[size]);
    }

    void addVerticallyFlippedQuad(const Rect& rect)
    {
        const float top = rect.top();
        const float right = rect.right() + 1;
        const float bottom = rect.bottom() + 1;
        const float left = rect.left();

        // Inverte top e bottom para flip vertical
        float arr[] = {
            left, bottom,
            right, bottom,
            left, top,
            left, top,
            right, bottom,
            right, top
        };

        const size_t size = sizeof(arr) / sizeof(float);
        m_buffer.insert(m_buffer.end(), &arr[0], &arr[size]);
    }


    void addUpsideDownQuad(const Rect& rect)
    {
        const float top = rect.top();
        const float right = rect.right() + 1;
        const float bottom = rect.bottom() + 1;
        const float left = rect.left();

        float arr[] = {
            left, bottom,
            right, bottom,
            left, top,
            right, top,
        };

        const size_t size = sizeof(arr) / sizeof(float);
        m_buffer.insert(m_buffer.end(), &arr[0], &arr[size]);
    }

    void addUpsideDownRect(const Rect& rect)
    {
        const float top = rect.top();
        const float right = rect.right() + 1;
        const float bottom = rect.bottom() + 1;
        const float left = rect.left();

        float arr[] = {
            left, bottom,
            right, bottom,
            left, bottom,
            left, top,
            right, bottom,
            right, top
        };

        const size_t size = sizeof(arr) / sizeof(float);
        m_buffer.insert(m_buffer.end(), &arr[0], &arr[size]);
    }

    void addFilledRoundedRect(const Rect& rect, const int radius)
    {
        if (radius <= 0 || rect.isEmpty()) {
            addRect(rect);
            return;
        }
        const int left = rect.left();
        const int right = rect.right() + 1;
        const int top = rect.top();
        const int bottom = rect.bottom() + 1;
        const int w = right - left;
        const int h = bottom - top;
        const int r = std::min(radius, std::min(w, h) / 2);
        if (r <= 0) {
            addRect(rect);
            return;
        }
        const float cx0 = static_cast<float>(left + r);
        const float cy0 = static_cast<float>(top + r);
        const float cx1 = static_cast<float>(right - r);
        const float cy1 = static_cast<float>(bottom - r);
        const float centerX = (left + right) * 0.5f;
        const float centerY = (top + bottom) * 0.5f;
        constexpr int segments = 8;
        constexpr float step = (3.14159265f * 0.5f) / segments;
        const float rf = static_cast<float>(r);

        // Build perimeter vertices in order (clockwise): top edge -> top-right arc -> right edge -> ... -> top-left arc
        std::vector<float> perimeter;
        auto addArc = [&perimeter, rf](float cx, float cy, float angleStart, float angleEnd) {
            for (int i = 1; i <= segments; ++i) {
                float t = static_cast<float>(i) / segments;
                float angle = angleStart + t * (angleEnd - angleStart);
                perimeter.push_back(cx + rf * std::cos(angle));
                perimeter.push_back(cy + rf * std::sin(angle));
            }
        };

        perimeter.push_back(static_cast<float>(left + r));
        perimeter.push_back(static_cast<float>(top));
        perimeter.push_back(static_cast<float>(right - r));
        perimeter.push_back(static_cast<float>(top));
        addArc(cx1, cy0, 3.14159265f * 1.5f, 3.14159265f * 2.f);
        perimeter.push_back(static_cast<float>(right));
        perimeter.push_back(static_cast<float>(top + r));
        perimeter.push_back(static_cast<float>(right));
        perimeter.push_back(static_cast<float>(bottom - r));
        addArc(cx1, cy1, 0.f, 3.14159265f * 0.5f);
        perimeter.push_back(static_cast<float>(right - r));
        perimeter.push_back(static_cast<float>(bottom));
        perimeter.push_back(static_cast<float>(left + r));
        perimeter.push_back(static_cast<float>(bottom));
        addArc(cx0, cy1, 3.14159265f * 0.5f, 3.14159265f);
        perimeter.push_back(static_cast<float>(left));
        perimeter.push_back(static_cast<float>(bottom - r));
        perimeter.push_back(static_cast<float>(left));
        perimeter.push_back(static_cast<float>(top + r));
        addArc(cx0, cy0, 3.14159265f, 3.14159265f * 1.5f);

        // Single triangle fan from center to consecutive perimeter points (one mesh, no gaps)
        const size_t n = perimeter.size() / 2;
        for (size_t i = 0; i < n; ++i) {
            const float* v0 = &perimeter[((i + 0) % n) * 2];
            const float* v1 = &perimeter[((i + 1) % n) * 2];
            const float tri[] = { centerX, centerY, v0[0], v0[1], v1[0], v1[1] };
            m_buffer.insert(m_buffer.end(), &tri[0], &tri[6]);
        }
    }

    void append(const VertexArray* buffer) {
        m_buffer.insert(m_buffer.end(), buffer->m_buffer.begin(), buffer->m_buffer.end());
    }

    void clear() { m_buffer.clear(); }

    const float* vertices() const { return m_buffer.data(); }
    int vertexCount() const { return m_buffer.size() / 2; }
    int size() const { return m_buffer.size(); }

private:
    std::vector<float> m_buffer;
};
