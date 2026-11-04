import { createRequire } from 'module';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);

var require = createRequire(import.meta.url);
var module = { exports: {} };

const config = {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};

export default config;
