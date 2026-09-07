# Security Headers Configuration

This document explains the security headers configured in `vercel.json`.

## Headers Overview

### 1. **X-DNS-Prefetch-Control**
- **Value**: `on`
- **Purpose**: Enables DNS prefetching for faster resource loading
- **Security Impact**: Low

### 2. **Strict-Transport-Security (HSTS)**
- **Value**: `max-age=63072000; includeSubDomains; preload`
- **Purpose**: Forces HTTPS connections for 2 years
- **Security Impact**: 🔒 High - Prevents MITM attacks
- **Note**: Requires HTTPS to be properly configured

### 3. **X-Frame-Options**
- **Value**: `SAMEORIGIN`
- **Purpose**: Prevents clickjacking by disallowing iframe embedding from other origins
- **Security Impact**: 🔒 High - Protects against clickjacking attacks
- **Alternative**: Can use `DENY` for stricter protection

### 4. **X-Content-Type-Options**
- **Value**: `nosniff`
- **Purpose**: Prevents MIME-type sniffing
- **Security Impact**: 🔒 Medium - Prevents XSS via MIME confusion

### 5. **X-XSS-Protection**
- **Value**: `1; mode=block`
- **Purpose**: Enables browser XSS filtering (legacy browsers)
- **Security Impact**: 🔒 Low - Modern browsers use CSP instead
- **Note**: Kept for compatibility with older browsers

### 6. **Referrer-Policy**
- **Value**: `strict-origin-when-cross-origin`
- **Purpose**: Controls how much referrer information is sent
- **Security Impact**: 🔒 Medium - Prevents information leakage
- **Behavior**: 
  - Same-origin: Full URL
  - Cross-origin HTTPS→HTTPS: Origin only
  - Cross-origin HTTPS→HTTP: No referrer

### 7. **Permissions-Policy**
- **Value**: `camera=(), microphone=(), geolocation=(), interest-cohort=()`
- **Purpose**: Disables browser features that aren't needed
- **Security Impact**: 🔒 Medium - Reduces attack surface
- **Features Disabled**:
  - Camera access
  - Microphone access
  - Geolocation
  - FLoC tracking

### 8. **Content-Security-Policy (CSP)**
- **Purpose**: Defines which resources can be loaded and executed
- **Security Impact**: 🔒 Critical - Primary defense against XSS

#### Current CSP Directives:
```
default-src 'self'
  └─ Only load resources from same origin by default

script-src 'self' 'unsafe-inline' 'unsafe-eval'
  └─ Scripts from same origin, inline scripts, and eval()
  └─ NOTE: 'unsafe-inline' and 'unsafe-eval' needed for React/Vite
  └─ TODO: Remove 'unsafe-*' in production with nonce-based CSP

style-src 'self' 'unsafe-inline'
  └─ Styles from same origin and inline styles
  └─ NOTE: 'unsafe-inline' needed for Tailwind CSS

img-src 'self' data: https: blob:
  └─ Images from same origin, data URLs, any HTTPS, and blobs

font-src 'self' data:
  └─ Fonts from same origin and data URLs

connect-src 'self' https://data.kms-connect.com wss://data.kms-connect.com https://*.kms-connect.com
  └─ API and WebSocket calls to the production backend (data.kms-connect.com)
  └─ Local Vite (`npm run dev`) is not gated by these headers — localhost is omitted on purpose

frame-ancestors 'self'
  └─ Only allow framing by same origin

base-uri 'self'
  └─ Restricts <base> tag URLs

form-action 'self'
  └─ Forms can only submit to same origin
```

## 📝 Production Checklist

Before deploying to production, confirm:

1. **CSP `connect-src`** already allows the production API:
   ```
   connect-src 'self' https://data.kms-connect.com wss://data.kms-connect.com https://*.kms-connect.com
   ```

2. **Localhost is not in production CSP.** Vite dev does not use `vercel.json` headers.

3. **Consider stricter CSP** (if possible):
   - Remove `'unsafe-inline'` and `'unsafe-eval'`
   - Use nonce or hash-based CSP
   - This requires build configuration changes

4. **Verify HTTPS** is enabled on Vercel

5. **Test all features** after deployment to ensure CSP doesn't break functionality

## 🧪 Testing Security Headers

### Online Tools:
- [Security Headers Scanner](https://securityheaders.com/)
- [Mozilla Observatory](https://observatory.mozilla.org/)
- [CSP Evaluator](https://csp-evaluator.withgoogle.com/)

### Browser DevTools:
1. Open browser DevTools (F12)
2. Go to Network tab
3. Reload page
4. Click on main document request
5. Check Response Headers

### Expected Security Score:
- Security Headers: A or A+
- Mozilla Observatory: B+ or higher

## 🔄 Cache Headers

Additional headers for performance:

### Static Assets (`/assets/*`)
- **Cache-Control**: `public, max-age=31536000, immutable`
- Assets with hashed filenames can be cached forever

### Images
- **Cache-Control**: `public, max-age=2592000, stale-while-revalidate=86400`
- Cached for 30 days with 1 day stale-while-revalidate

### Fonts
- **Cache-Control**: `public, max-age=31536000, immutable`
- **CORS**: `Access-Control-Allow-Origin: *` for cross-origin font loading

## 🚨 Common Issues

### CSP Blocks Resources
**Symptom**: Console errors like "Refused to load..."
**Solution**: Add the domain to appropriate CSP directive

### Mixed Content Warnings
**Symptom**: HTTP resources blocked on HTTPS page
**Solution**: Ensure all resources use HTTPS URLs

### HSTS Not Working
**Symptom**: Browser doesn't enforce HTTPS
**Solution**: Headers only apply after first HTTPS visit, or use preload list

## 📚 Resources

- [OWASP Secure Headers Project](https://owasp.org/www-project-secure-headers/)
- [MDN CSP Guide](https://developer.mozilla.org/en-US/docs/Web/HTTP/CSP)
- [Content Security Policy Reference](https://content-security-policy.com/)
