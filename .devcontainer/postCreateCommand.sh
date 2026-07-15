#!/bin/bash
corepack enable pnpm
corepack prepare pnpm@latest --activate 
pnpm config set store-dir ~/.pnpm-store
pnpm add -g @playwright/test@1.60.0
curl -fsSL https://opencode.ai/install | bash
