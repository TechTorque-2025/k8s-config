# Namecheap DNS Configuration Guide

This guide shows you how to configure DNS records in Namecheap for your TechTorque deployment.

## Overview

You need to add DNS records to point your subdomains to your Azure server.

### Domains You'll Configure

| Domain | Points To | Environment |
|--------|-----------|-------------|
| techtorque.randitha.net | Azure Server IP | Production Frontend |
| api.techtorque.randitha.net | Azure Server IP | Production API |
| dev.techtorque.randitha.net | Azure Server IP | Dev Frontend |
| api-dev.techtorque.randitha.net | Azure Server IP | Dev API |
| argocd.techtorque.randitha.net | Azure Server IP | ArgoCD UI |

## Step 1: Get Your Server IP

On your Azure server, run:

```bash
curl ifconfig.me
```

**Example output**: `20.123.45.67`

Save this IP - you'll need it for DNS configuration.

## Step 2: Login to Namecheap

1. Go to https://www.namecheap.com/
2. Click **Sign In**
3. Enter your username and password
4. Navigate to **Domain List**

## Step 3: Access DNS Settings

1. Find **randitha.net** in your domain list
2. Click **Manage** button next to it
3. Click **Advanced DNS** tab

You should see the DNS records page.

## Step 4: Add DNS Records

### Option A: Using A Records (Recommended)

Add these A Records:

| Type | Host | Value | TTL |
|------|------|-------|-----|
| A Record | techtorque | YOUR_SERVER_IP | Automatic |
| A Record | api.techtorque | YOUR_SERVER_IP | Automatic |
| A Record | dev.techtorque | YOUR_SERVER_IP | Automatic |
| A Record | api-dev.techtorque | YOUR_SERVER_IP | Automatic |
| A Record | argocd.techtorque | YOUR_SERVER_IP | Automatic |

**How to add each record**:

1. Click **Add New Record**
2. Select **Type**: `A Record`
3. Enter **Host**: (see table above, e.g., `techtorque`)
4. Enter **Value**: Your server IP (e.g., `20.123.45.67`)
5. Leave **TTL**: `Automatic`
6. Click **Save Changes** (green checkmark)

### Option B: Using CNAME Records (Easier to Maintain)

First, make sure you have the base A Record:

| Type | Host | Value | TTL |
|------|------|-------|-----|
| A Record | techtorque | YOUR_SERVER_IP | Automatic |

Then add CNAME records for everything else:

| Type | Host | Value | TTL |
|------|------|-------|-----|
| CNAME Record | api.techtorque | techtorque.randitha.net. | Automatic |
| CNAME Record | dev.techtorque | techtorque.randitha.net. | Automatic |
| CNAME Record | api-dev.techtorque | techtorque.randitha.net. | Automatic |
| CNAME Record | argocd.techtorque | techtorque.randitha.net. | Automatic |

**Note**: The trailing dot (`.`) in CNAME values is important!

**How to add CNAME**:

1. Click **Add New Record**
2. Select **Type**: `CNAME Record`
3. Enter **Host**: (e.g., `api.techtorque`)
4. Enter **Value**: `techtorque.randitha.net.` (with trailing dot)
5. Leave **TTL**: `Automatic`
6. Click **Save Changes**

### Which Option Should You Choose?

**Use A Records if:**
- You want maximum control
- Your server IP rarely changes
- You want slightly faster DNS resolution

**Use CNAME Records if:**
- You want easier maintenance (change IP once)
- Your server IP might change in the future
- You prefer cleaner configuration

**Recommendation**: Use **Option B (CNAME)** - easier to maintain.

## Step 5: Verify DNS Records

After adding records, your DNS list should look like this:

```
Type        Host              Value                          TTL
────────────────────────────────────────────────────────────────────
A Record    techtorque        20.123.45.67                   Automatic
CNAME       api.techtorque    techtorque.randitha.net.       Automatic
CNAME       dev.techtorque    techtorque.randitha.net.       Automatic
CNAME       api-dev.techtorque techtorque.randitha.net.      Automatic
CNAME       argocd.techtorque techtorque.randitha.net.       Automatic
```

Click **Save All Changes** at the bottom.

## Step 6: Wait for DNS Propagation

DNS changes take time to propagate:
- **Typical**: 5-30 minutes
- **Maximum**: Up to 48 hours (rare)

### Check DNS Propagation

From your local machine or server:

```bash
# Check if DNS is resolving
nslookup techtorque.randitha.net
nslookup dev.techtorque.randitha.net
nslookup api-dev.techtorque.randitha.net
nslookup argocd.techtorque.randitha.net

# Or use dig
dig techtorque.randitha.net +short
dig dev.techtorque.randitha.net +short
```

Expected output should show your server IP.

### Online DNS Checker

Check propagation worldwide:
- https://dnschecker.org/
- Enter: `dev.techtorque.randitha.net`
- Select: `A` or `CNAME`
- Click **Search**

Green checkmarks = propagated ✅

## Step 7: Test Domains (After Propagation)

Once DNS is propagated, test each domain:

```bash
# Test if domains resolve
curl -I https://techtorque.randitha.net
curl -I https://dev.techtorque.randitha.net
curl -I https://api-dev.techtorque.randitha.net
curl -I https://argocd.techtorque.randitha.net
```

## Common Issues & Solutions

### Issue 1: "Host record already exists"

**Problem**: Namecheap shows error when adding record.

**Solution**:
- You might already have a conflicting record
- Check existing records and delete duplicates
- Make sure you're not adding both A and CNAME for the same host

### Issue 2: DNS Not Resolving After 30 Minutes

**Problem**: `nslookup` shows no results.

**Solutions**:

1. **Check Namecheap Nameservers**:
   - Go to **Domain** tab (not Advanced DNS)
   - Verify **Nameservers** are set to **Namecheap BasicDNS** or **Namecheap PremiumDNS**
   - If set to custom nameservers, your DNS records won't work

2. **Clear Local DNS Cache**:
   ```bash
   # On Ubuntu/Linux
   sudo systemd-resolve --flush-caches

   # On macOS
   sudo dscacheutil -flushcache

   # On Windows
   ipconfig /flushdns
   ```

3. **Check DNS Records Are Saved**:
   - Go back to Advanced DNS
   - Verify records are still there
   - Click **Save All Changes** again

### Issue 3: Wrong IP Showing

**Problem**: DNS resolves to wrong IP address.

**Solution**:
- Delete the incorrect record
- Add new record with correct IP
- Wait for propagation
- Clear your DNS cache

### Issue 4: CNAME Not Working

**Problem**: CNAME record not resolving.

**Common Mistakes**:
```
Wrong: techtorque.randitha.net     (missing dot)
Wrong: techtorque.randitha.net/    (slash instead of dot)
Right: techtorque.randitha.net.    (trailing dot)
```

**Solution**: Add trailing dot (`.`) to CNAME values.

### Issue 5: Namecheap Parking Page Shows

**Problem**: Going to domain shows Namecheap parking page.

**Causes**:
1. DNS not propagated yet (wait longer)
2. Server not responding on port 80/443
3. Traefik ingress not configured

**Solution**:
```bash
# Check if server is listening
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :443

# Check Traefik
kubectl get pods -n kube-system | grep traefik

# Check ingress
kubectl get ingressroute -n default
kubectl get ingressroute -n dev
```

## Screenshot Guide

### Adding A Record

1. **Click "Add New Record"**
   - Green button at bottom of DNS records

2. **Select Record Type**
   - Dropdown: Choose "A Record"

3. **Fill in Details**
   ```
   Type: A Record
   Host: techtorque
   Value: 20.123.45.67
   TTL: Automatic
   ```

4. **Save**
   - Click green checkmark icon

### Adding CNAME Record

1. **Click "Add New Record"**

2. **Select Record Type**
   - Dropdown: Choose "CNAME Record"

3. **Fill in Details**
   ```
   Type: CNAME Record
   Host: dev.techtorque
   Value: techtorque.randitha.net.
   TTL: Automatic
   ```

4. **Save**
   - Click green checkmark icon

## Namecheap-Specific Notes

### TTL Settings

Namecheap's "Automatic" TTL is typically:
- **A Records**: 1800 seconds (30 minutes)
- **CNAME Records**: 1800 seconds (30 minutes)

You can manually set TTL if needed:
- **1 min** - Fastest propagation, more DNS queries
- **5 min** - Good balance (300 seconds)
- **30 min** - Default (1800 seconds)
- **1 hour** - Slower propagation, fewer queries

### URL Redirect vs DNS Record

**Don't confuse**:
- **DNS Record** (what you need) - Points domain to IP
- **URL Redirect** (not needed) - Redirects one domain to another

You need **DNS Records**, not URL Redirects.

### Email Records

If you have email on this domain, be careful:
- Don't delete MX records (for email)
- Don't delete TXT records (for SPF, DKIM)
- Only add A/CNAME records for subdomains

## Complete DNS Setup

### Final Configuration

After setup, your Namecheap Advanced DNS should have:

```
MAIL SETTINGS (if you have email)
────────────────────────────────
MX Record    @    mail.yourdomain.com    10    Automatic

YOUR APPLICATION RECORDS
────────────────────────────────
A Record     techtorque              20.123.45.67              Automatic
CNAME        api.techtorque          techtorque.randitha.net.  Automatic
CNAME        dev.techtorque          techtorque.randitha.net.  Automatic
CNAME        api-dev.techtorque      techtorque.randitha.net.  Automatic
CNAME        argocd.techtorque       techtorque.randitha.net.  Automatic
```

## Next Steps

After DNS is configured and propagated:

1. **Deploy Dev Ingress**:
   ```bash
   kubectl apply -f k8s-config/argocd/environments/dev-ingress.yaml
   ```

2. **Configure ArgoCD Ingress**:
   ```bash
   cd k8s-config/argocd
   sudo ./configure-ingress.sh
   ```

3. **Wait for Certificates**:
   ```bash
   kubectl get certificates -n dev
   kubectl get certificates -n argocd
   ```

4. **Access Your Services**:
   - Production: https://techtorque.randitha.net
   - Dev: https://dev.techtorque.randitha.net
   - ArgoCD: https://argocd.techtorque.randitha.net

## Support

If you encounter issues:

1. **Namecheap Support**:
   - Live Chat: https://www.namecheap.com/support/live-chat/
   - Knowledge Base: https://www.namecheap.com/support/knowledgebase/

2. **DNS Troubleshooting Tools**:
   - https://dnschecker.org/
   - https://www.whatsmydns.net/
   - `nslookup` command
   - `dig` command

3. **Common Issues**:
   - Wait 30 minutes for propagation
   - Clear local DNS cache
   - Verify nameservers are Namecheap DNS
   - Check for typos in records

---
**DNS Provider**: Namecheap
**Propagation Time**: 5-30 minutes typically
**Records Needed**: 1 A Record + 4 CNAME Records
**Cost**: Free (included with domain)
