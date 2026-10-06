#!/usr/bin/env python3
"""
End-to-End Infrastructure & Health Check Validation Script
Validates:
1. HTTP -> HTTPS 301 Redirection
2. HTTPS ALB Availability
3. Backend ASG Instance Health Check (/health)
4. Application Operational Status (/)
5. Database Connectivity & Query Verification (/db-check)
6. EC2 IMDSv2 Metadata (/info)
"""

import sys
import json
import urllib.request
import urllib.error
import ssl
import time

def print_header(title):
    print("\n" + "=" * 70)
    print(f" {title}")
    print("=" * 70)

def test_http_redirect(alb_dns):
    url = f"http://{alb_dns}/health"
    print(f"\n[TEST 1] Testing HTTP -> HTTPS 301 Redirect: {url}")
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'ValidationScript/1.0'})
        # Custom opener to prevent automatic redirect following
        class NoRedirectHandler(urllib.request.HTTPRedirectHandler):
            def http_error_301(self, req, fp, code, msg, headers):
                return fp
            def http_error_302(self, req, fp, code, msg, headers):
                return fp

        opener = urllib.request.build_opener(NoRedirectHandler)
        resp = opener.open(req, timeout=10)
        location = resp.headers.get('Location', '')
        print(f"  Status Code: {resp.status}")
        print(f"  Redirect Location: {location}")
        if resp.status == 301 and location.startswith('https://'):
            print("  ==> PASSED: HTTP correctly redirected to HTTPS 301.")
            return True
        else:
            print(f"  ==> FAILED: Expected 301 redirect to HTTPS, got status {resp.status}")
            return False
    except Exception as e:
        print(f"  ==> WARNING / ERROR: {e}")
        return False

def test_endpoint(name, url, expected_status=200):
    print(f"\n[TEST] {name}: {url}")
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE  # Permissive for self-signed or staging certs

    try:
        start_time = time.time()
        req = urllib.request.Request(url, headers={'User-Agent': 'ValidationScript/1.0'})
        with urllib.request.urlopen(req, context=ctx, timeout=15) as resp:
            duration_ms = round((time.time() - start_time) * 1000, 2)
            body = resp.read().decode('utf-8')
            print(f"  Status Code: {resp.status} (Latency: {duration_ms}ms)")
            try:
                data = json.loads(body)
                print(f"  Response Body: {json.dumps(data, indent=2)}")
                if resp.status == expected_status:
                    print(f"  ==> PASSED: {name}")
                    return True, data
            except json.JSONDecodeError:
                print(f"  Response Body (Text): {body[:200]}")
                if resp.status == expected_status:
                    print(f"  ==> PASSED: {name}")
                    return True, body
    except urllib.error.HTTPError as e:
        print(f"  ==> FAILED: HTTP Error {e.code} - {e.reason}")
        return False, None
    except Exception as e:
        print(f"  ==> FAILED: Connection error: {e}")
        return False, None
    return False, None

def main():
    if len(sys.argv) < 2:
        print("Usage: python validate_deployment.py <ALB_DNS_NAME_OR_DOMAIN>")
        print("Example: python validate_deployment.py savitara-dev-alb-123456.us-east-1.elb.amazonaws.com")
        sys.exit(1)

    alb_host = sys.argv[1].replace("https://", "").replace("http://", "").split("/")[0]

    print_header(f"VALIDATING DEPLOYMENT FOR HOST: {alb_host}")

    results = []

    # 1. HTTP Redirect Test
    res1 = test_http_redirect(alb_host)
    results.append(("HTTP -> HTTPS 301 Redirect", res1))

    # 2. HTTPS Health Check (/health)
    res2, _ = test_endpoint("ALB Target Group Health Check", f"https://{alb_host}/health")
    results.append(("/health Endpoint", res2))

    # 3. Main Operational Dashboard (/)
    res3, data3 = test_endpoint("Main Architecture Dashboard", f"https://{alb_host}/")
    results.append(("/ Endpoint", res3))

    # 4. Database Connectivity Check (/db-check)
    res4, _ = test_endpoint("RDS Database Connectivity", f"https://{alb_host}/db-check")
    results.append(("/db-check Endpoint", res4))

    # 5. Runtime EC2 Metadata (/info)
    res5, _ = test_endpoint("Compute Metadata & Diagnostics", f"https://{alb_host}/info")
    results.append(("/info Endpoint", res5))

    # Summary Table
    print_header("VALIDATION SUMMARY")
    all_passed = True
    for test_name, passed in results:
        status_str = "PASS [OK]" if passed else "FAIL [X]"
        print(f"  {test_name:<40} : {status_str}")
        if not passed:
            all_passed = False

    print("=" * 70)
    if all_passed:
        print(" ALL END-TO-END VERIFICATION CHECKS PASSED SUCCESSFULLY! 🚀")
        sys.exit(0)
    else:
        print(" SOME CHECKS FAILED OR RETURNED WARNINGS. Check logs above.")
        sys.exit(1)

if __name__ == "__main__":
    main()
