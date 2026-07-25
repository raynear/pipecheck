/// 법적 문서 HTML 템플릿 생성.
///
/// 개인정보처리방침(Privacy Policy)과 이용약관(Terms of Service)의
/// HTML 콘텐츠를 생성하는 함수들을 포함합니다.
library;

/// 개인정보처리방침 HTML을 생성합니다.
String generatePrivacyPolicy({
  required String appName,
  required String contactEmail,
  required String effectiveDate,
  required String privacyPolicyUrl,
  required bool firebaseEnabled,
  required bool adsEnabled,
  required bool subscriptionEnabled,
}) {
  final buffer = StringBuffer();

  buffer.writeln('<!DOCTYPE html>');
  buffer.writeln('<html lang="en">');
  buffer.writeln('<head>');
  buffer.writeln('  <meta charset="UTF-8">');
  buffer.writeln(
      '  <meta name="viewport" '
      'content="width=device-width, initial-scale=1.0">');
  buffer.writeln('  <title>Privacy Policy - $appName</title>');
  buffer.writeln('  <style>');
  buffer.writeln(commonStyles());
  buffer.writeln('  </style>');
  buffer.writeln('</head>');
  buffer.writeln('<body>');
  buffer.writeln('  <div class="container">');
  buffer.writeln('    <h1>Privacy Policy</h1>');
  buffer.writeln(
      '    <p class="effective-date">'
      'Effective Date: $effectiveDate</p>');
  buffer.writeln('');

  // Introduction
  buffer.writeln('    <p>');
  buffer.writeln(
      '      This Privacy Policy describes how $appName '
      '("we", "our", or "us") collects, uses, and shares ');
  buffer.writeln(
      '      information when you use our mobile application '
      '(the "App"). By using the App, you agree to the ');
  buffer.writeln(
      '      collection and use of information in accordance '
      'with this policy.');
  buffer.writeln('    </p>');
  buffer.writeln('');

  // Information We Collect
  buffer.writeln('    <h2>1. Information We Collect</h2>');
  buffer.writeln('');
  buffer.writeln('    <h3>Information You Provide</h3>');
  buffer.writeln('    <ul>');
  buffer.writeln(
      '      <li>Account information (such as name and email address) '
      'if you create an account</li>');
  buffer.writeln(
      '      <li>Content and data you input into the App</li>');
  buffer.writeln(
      '      <li>Feedback, support requests, or correspondence '
      'you send to us</li>');
  buffer.writeln('    </ul>');
  buffer.writeln('');
  buffer.writeln('    <h3>Information Collected Automatically</h3>');
  buffer.writeln('    <ul>');
  buffer.writeln(
      '      <li>Device information (device model, operating system '
      'version, unique device identifiers)</li>');
  buffer.writeln(
      '      <li>Usage data (features used, actions taken, '
      'time and duration of use)</li>');
  buffer.writeln(
      '      <li>Log data (crash reports, performance data)</li>');
  buffer.writeln('    </ul>');
  buffer.writeln('');

  // How We Use Information
  buffer.writeln('    <h2>2. How We Use Information</h2>');
  buffer.writeln('    <p>We use the information we collect to:</p>');
  buffer.writeln('    <ul>');
  buffer.writeln(
      '      <li>Provide, maintain, and improve the App</li>');
  buffer.writeln(
      '      <li>Personalize your experience</li>');
  buffer.writeln(
      '      <li>Respond to your requests and provide '
      'customer support</li>');
  buffer.writeln(
      '      <li>Send technical notices and security alerts</li>');
  buffer.writeln(
      '      <li>Monitor and analyze trends, usage, '
      'and activities</li>');
  buffer.writeln(
      '      <li>Detect, investigate, and prevent '
      'fraudulent or unauthorized activity</li>');
  buffer.writeln('    </ul>');
  buffer.writeln('');

  // Data Storage and Security
  buffer.writeln('    <h2>3. Data Storage and Security</h2>');
  buffer.writeln('    <p>');
  buffer.writeln(
      '      We implement appropriate technical and organizational '
      'security measures to protect your personal information ');
  buffer.writeln(
      '      against unauthorized access, alteration, disclosure, '
      'or destruction. However, no method of transmission over ');
  buffer.writeln(
      '      the Internet or electronic storage is 100% secure, '
      'and we cannot guarantee absolute security.');
  buffer.writeln('    </p>');
  buffer.writeln('    <p>');
  buffer.writeln(
      '      Data may be stored locally on your device and/or '
      'on secure cloud servers. We retain your information only ');
  buffer.writeln(
      '      for as long as necessary to fulfill the purposes '
      'outlined in this policy.');
  buffer.writeln('    </p>');
  buffer.writeln('');

  // Analytics and Tracking (conditional)
  if (firebaseEnabled) {
    buffer.writeln('    <h2>4. Analytics and Tracking</h2>');
    buffer.writeln('    <p>');
    buffer.writeln(
        '      We use analytics services, including Firebase Analytics '
        'and Firebase Crashlytics, to help us understand how ');
    buffer.writeln(
        '      users interact with the App. These services may '
        'collect information such as:');
    buffer.writeln('    </p>');
    buffer.writeln('    <ul>');
    buffer.writeln(
        '      <li>How often you use the App and which features '
        'you use</li>');
    buffer.writeln(
        '      <li>App performance data and crash reports</li>');
    buffer.writeln(
        '      <li>Device and operating system information</li>');
    buffer.writeln(
        '      <li>Approximate location (country/region level)</li>');
    buffer.writeln('    </ul>');
    buffer.writeln('    <p>');
    buffer.writeln(
        '      This data is aggregated and anonymized where '
        'possible. You can opt out of analytics data collection ');
    buffer.writeln(
        '      through your device settings.');
    buffer.writeln('    </p>');
    buffer.writeln('');
  }

  // Advertising (conditional)
  final adsSectionNum = firebaseEnabled ? 5 : 4;
  if (adsEnabled) {
    buffer.writeln('    <h2>$adsSectionNum. Advertising</h2>');
    buffer.writeln('    <p>');
    buffer.writeln(
        '      The App may display advertisements provided by '
        'third-party advertising networks, including Google AdMob. ');
    buffer.writeln(
        '      These networks may use cookies, device identifiers, '
        'and similar technologies to serve personalized ads ');
    buffer.writeln('      based on your interests.');
    buffer.writeln('    </p>');
    buffer.writeln('    <p>');
    buffer.writeln(
        '      You can manage your advertising preferences through '
        'your device settings. On iOS, you can enable ');
    buffer.writeln(
        '      "Limit Ad Tracking" in your privacy settings. '
        'On Android, you can opt out of personalized ads ');
    buffer.writeln(
        '      in your Google settings.');
    buffer.writeln('    </p>');
    buffer.writeln('');
  }

  // In-App Purchases (conditional)
  final iapSectionNum = adsSectionNum + (adsEnabled ? 1 : 0);
  if (subscriptionEnabled) {
    buffer.writeln(
        '    <h2>$iapSectionNum. In-App Purchases '
        'and Subscriptions</h2>');
    buffer.writeln('    <p>');
    buffer.writeln(
        '      The App may offer in-app purchases or subscriptions. '
        'Payment processing is handled by the respective ');
    buffer.writeln(
        '      app store (Apple App Store or Google Play Store). '
        'We do not directly collect or store your payment ');
    buffer.writeln(
        '      information. Please refer to the app store\'s '
        'privacy policy for details on payment data handling.');
    buffer.writeln('    </p>');
    buffer.writeln('    <p>');
    buffer.writeln(
        '      We may receive transaction confirmations and '
        'subscription status information from the app store ');
    buffer.writeln(
        '      to manage your access to premium features.');
    buffer.writeln('    </p>');
    buffer.writeln('');
  }

  // Third-Party Services
  final thirdPartySectionNum =
      iapSectionNum + (subscriptionEnabled ? 1 : 0);
  buffer.writeln(
      '    <h2>$thirdPartySectionNum. Third-Party Services</h2>');
  buffer.writeln('    <p>');
  buffer.writeln(
      '      The App may contain links to or integrate with '
      'third-party services. We are not responsible for the ');
  buffer.writeln(
      '      privacy practices of these services. We encourage you '
      'to review the privacy policies of any third-party ');
  buffer.writeln(
      '      services you interact with.');
  buffer.writeln('    </p>');
  buffer.writeln('');

  // Children's Privacy
  final childrenSectionNum = thirdPartySectionNum + 1;
  buffer.writeln(
      '    <h2>$childrenSectionNum. Children\'s Privacy</h2>');
  buffer.writeln('    <p>');
  buffer.writeln(
      '      The App is not intended for children under the age '
      'of 13. We do not knowingly collect personal information ');
  buffer.writeln(
      '      from children under 13. If we become aware that we '
      'have collected personal information from a child ');
  buffer.writeln(
      '      under 13, we will take steps to delete such '
      'information promptly.');
  buffer.writeln('    </p>');
  buffer.writeln('');

  // Your Rights
  final rightsSectionNum = childrenSectionNum + 1;
  buffer.writeln('    <h2>$rightsSectionNum. Your Rights</h2>');
  buffer.writeln(
      '    <p>Depending on your jurisdiction, you may have '
      'the right to:</p>');
  buffer.writeln('    <ul>');
  buffer.writeln(
      '      <li>Access, correct, or delete your '
      'personal information</li>');
  buffer.writeln(
      '      <li>Object to or restrict certain processing '
      'of your data</li>');
  buffer.writeln(
      '      <li>Request a copy of your data in a '
      'portable format</li>');
  buffer.writeln(
      '      <li>Withdraw consent at any time where processing '
      'is based on consent</li>');
  buffer.writeln('    </ul>');
  buffer.writeln('    <p>');
  buffer.writeln(
      '      To exercise any of these rights, please contact us '
      'at <a href="mailto:$contactEmail">$contactEmail</a>.');
  buffer.writeln('    </p>');
  buffer.writeln('');

  // Changes to This Policy
  final changesSectionNum = rightsSectionNum + 1;
  buffer.writeln(
      '    <h2>$changesSectionNum. Changes to This Policy</h2>');
  buffer.writeln('    <p>');
  buffer.writeln(
      '      We may update this Privacy Policy from time to time. '
      'We will notify you of any changes by posting the new ');
  buffer.writeln(
      '      Privacy Policy within the App and updating the '
      '"Effective Date" at the top of this page. You are advised ');
  buffer.writeln(
      '      to review this Privacy Policy periodically for '
      'any changes.');
  buffer.writeln('    </p>');
  buffer.writeln('');

  // Contact Us
  final contactSectionNum = changesSectionNum + 1;
  buffer.writeln('    <h2>$contactSectionNum. Contact Us</h2>');
  buffer.writeln('    <p>');
  buffer.writeln(
      '      If you have any questions about this Privacy Policy, '
      'please contact us at:');
  buffer.writeln('    </p>');
  buffer.writeln('    <p>');
  buffer.writeln(
      '      Email: <a href="mailto:$contactEmail">'
      '$contactEmail</a>');
  buffer.writeln('    </p>');

  buffer.writeln('  </div>');
  buffer.writeln('</body>');
  buffer.writeln('</html>');

  return buffer.toString();
}

/// 이용약관 HTML을 생성합니다.
String generateTermsOfService({
  required String appName,
  required String contactEmail,
  required String effectiveDate,
  required String termsOfServiceUrl,
  required bool authEnabled,
  required bool subscriptionEnabled,
}) {
  final buffer = StringBuffer();

  buffer.writeln('<!DOCTYPE html>');
  buffer.writeln('<html lang="en">');
  buffer.writeln('<head>');
  buffer.writeln('  <meta charset="UTF-8">');
  buffer.writeln(
      '  <meta name="viewport" '
      'content="width=device-width, initial-scale=1.0">');
  buffer.writeln('  <title>Terms of Service - $appName</title>');
  buffer.writeln('  <style>');
  buffer.writeln(commonStyles());
  buffer.writeln('  </style>');
  buffer.writeln('</head>');
  buffer.writeln('<body>');
  buffer.writeln('  <div class="container">');
  buffer.writeln('    <h1>Terms of Service</h1>');
  buffer.writeln(
      '    <p class="effective-date">'
      'Effective Date: $effectiveDate</p>');
  buffer.writeln('');

  // Acceptance of Terms
  buffer.writeln('    <h2>1. Acceptance of Terms</h2>');
  buffer.writeln('    <p>');
  buffer.writeln(
      '      By downloading, installing, or using $appName '
      '(the "App"), you agree to be bound by these Terms of ');
  buffer.writeln(
      '      Service ("Terms"). If you do not agree to these '
      'Terms, do not use the App.');
  buffer.writeln('    </p>');
  buffer.writeln('');

  // Use of the App
  buffer.writeln('    <h2>2. Use of the App</h2>');
  buffer.writeln('    <p>You agree to use the App only for lawful '
      'purposes and in accordance with these Terms. '
      'You agree not to:</p>');
  buffer.writeln('    <ul>');
  buffer.writeln(
      '      <li>Use the App in any way that violates applicable '
      'laws or regulations</li>');
  buffer.writeln(
      '      <li>Attempt to gain unauthorized access to any part '
      'of the App or its systems</li>');
  buffer.writeln(
      '      <li>Interfere with or disrupt the App or servers '
      'connected to the App</li>');
  buffer.writeln(
      '      <li>Reverse engineer, decompile, or disassemble '
      'any part of the App</li>');
  buffer.writeln(
      '      <li>Use the App to transmit harmful, offensive, '
      'or illegal content</li>');
  buffer.writeln('    </ul>');
  buffer.writeln('');

  // User Accounts (conditional)
  var sectionNum = 3;
  if (authEnabled) {
    buffer.writeln('    <h2>$sectionNum. User Accounts</h2>');
    buffer.writeln('    <p>');
    buffer.writeln(
        '      You may be required to create an account to access '
        'certain features of the App. You are responsible for:');
    buffer.writeln('    </p>');
    buffer.writeln('    <ul>');
    buffer.writeln(
        '      <li>Maintaining the confidentiality of your '
        'account credentials</li>');
    buffer.writeln(
        '      <li>All activities that occur under '
        'your account</li>');
    buffer.writeln(
        '      <li>Notifying us immediately of any unauthorized '
        'use of your account</li>');
    buffer.writeln('    </ul>');
    buffer.writeln('    <p>');
    buffer.writeln(
        '      We reserve the right to suspend or terminate your '
        'account if we suspect any unauthorized or fraudulent ');
    buffer.writeln('      activity.');
    buffer.writeln('    </p>');
    buffer.writeln('');
    sectionNum++;
  }

  // Subscriptions and Payments (conditional)
  if (subscriptionEnabled) {
    buffer.writeln(
        '    <h2>$sectionNum. Subscriptions and Payments</h2>');
    buffer.writeln('    <p>');
    buffer.writeln(
        '      The App may offer subscription-based or one-time '
        'purchase features. By purchasing a subscription or ');
    buffer.writeln(
        '      in-app item, you agree to the pricing and payment '
        'terms presented at the time of purchase.');
    buffer.writeln('    </p>');
    buffer.writeln('    <ul>');
    buffer.writeln(
        '      <li>Subscriptions automatically renew unless '
        'canceled before the renewal date</li>');
    buffer.writeln(
        '      <li>You can manage or cancel subscriptions through '
        'the App Store or Google Play Store</li>');
    buffer.writeln(
        '      <li>Refunds are subject to the refund policies of '
        'the respective app store</li>');
    buffer.writeln(
        '      <li>We reserve the right to change subscription '
        'pricing with prior notice</li>');
    buffer.writeln('    </ul>');
    buffer.writeln('');
    sectionNum++;
  }

  // Intellectual Property
  buffer.writeln(
      '    <h2>$sectionNum. Intellectual Property</h2>');
  buffer.writeln('    <p>');
  buffer.writeln(
      '      The App and its original content, features, and '
      'functionality are owned by $appName and are protected by ');
  buffer.writeln(
      '      international copyright, trademark, patent, trade '
      'secret, and other intellectual property laws.');
  buffer.writeln('    </p>');
  buffer.writeln('    <p>');
  buffer.writeln(
      '      You are granted a limited, non-exclusive, '
      'non-transferable license to use the App for personal, ');
  buffer.writeln(
      '      non-commercial purposes in accordance with '
      'these Terms.');
  buffer.writeln('    </p>');
  buffer.writeln('');
  sectionNum++;

  // User Content
  buffer.writeln('    <h2>$sectionNum. User Content</h2>');
  buffer.writeln('    <p>');
  buffer.writeln(
      '      You retain ownership of any content you create or '
      'input into the App. By using the App, you grant us a ');
  buffer.writeln(
      '      limited license to process your content solely for '
      'the purpose of providing the App\'s functionality.');
  buffer.writeln('    </p>');
  buffer.writeln('    <p>');
  buffer.writeln(
      '      You are solely responsible for the content you '
      'create and must ensure it does not violate any ');
  buffer.writeln(
      '      applicable laws or third-party rights.');
  buffer.writeln('    </p>');
  buffer.writeln('');
  sectionNum++;

  // Disclaimers
  buffer.writeln('    <h2>$sectionNum. Disclaimers</h2>');
  buffer.writeln('    <p>');
  buffer.writeln(
      '      The App is provided on an "AS IS" and "AS AVAILABLE" '
      'basis without warranties of any kind, either express ');
  buffer.writeln(
      '      or implied, including but not limited to implied '
      'warranties of merchantability, fitness for a particular ');
  buffer.writeln(
      '      purpose, and non-infringement.');
  buffer.writeln('    </p>');
  buffer.writeln('');
  sectionNum++;

  // Limitation of Liability
  buffer.writeln(
      '    <h2>$sectionNum. Limitation of Liability</h2>');
  buffer.writeln('    <p>');
  buffer.writeln(
      '      To the maximum extent permitted by applicable law, '
      '$appName shall not be liable for any indirect, incidental, ');
  buffer.writeln(
      '      special, consequential, or punitive damages, '
      'including but not limited to loss of data, profits, ');
  buffer.writeln(
      '      or goodwill, arising out of or in connection with '
      'your use of the App.');
  buffer.writeln('    </p>');
  buffer.writeln('');
  sectionNum++;

  // Termination
  buffer.writeln('    <h2>$sectionNum. Termination</h2>');
  buffer.writeln('    <p>');
  buffer.writeln(
      '      We may terminate or suspend your access to the App '
      'at any time, without prior notice, for any reason, ');
  buffer.writeln(
      '      including if you breach these Terms. Upon '
      'termination, your right to use the App ceases immediately.');
  buffer.writeln('    </p>');
  buffer.writeln('    <p>');
  buffer.writeln(
      '      You may stop using the App at any time by '
      'uninstalling it from your device.');
  buffer.writeln('    </p>');
  buffer.writeln('');
  sectionNum++;

  // Governing Law
  buffer.writeln('    <h2>$sectionNum. Governing Law</h2>');
  buffer.writeln('    <p>');
  buffer.writeln(
      '      These Terms shall be governed by and construed in '
      'accordance with the laws of the jurisdiction in which ');
  buffer.writeln(
      '      the App operator is based, without regard to '
      'conflict of law provisions.');
  buffer.writeln('    </p>');
  buffer.writeln('');
  sectionNum++;

  // Changes to Terms
  buffer.writeln(
      '    <h2>$sectionNum. Changes to Terms</h2>');
  buffer.writeln('    <p>');
  buffer.writeln(
      '      We reserve the right to modify these Terms at any '
      'time. We will notify you of material changes by posting ');
  buffer.writeln(
      '      the updated Terms within the App and updating the '
      '"Effective Date." Your continued use of the App after ');
  buffer.writeln(
      '      changes constitutes acceptance of the revised Terms.');
  buffer.writeln('    </p>');
  buffer.writeln('');
  sectionNum++;

  // Contact Information
  buffer.writeln(
      '    <h2>$sectionNum. Contact Information</h2>');
  buffer.writeln('    <p>');
  buffer.writeln(
      '      If you have any questions about these Terms, '
      'please contact us at:');
  buffer.writeln('    </p>');
  buffer.writeln('    <p>');
  buffer.writeln(
      '      Email: <a href="mailto:$contactEmail">'
      '$contactEmail</a>');
  buffer.writeln('    </p>');

  buffer.writeln('  </div>');
  buffer.writeln('</body>');
  buffer.writeln('</html>');

  return buffer.toString();
}

/// 모바일 친화적 공통 CSS 스타일을 반환합니다.
String commonStyles() {
  return '''
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI",
        Roboto, "Helvetica Neue", Arial, sans-serif;
      font-size: 16px;
      line-height: 1.6;
      color: #333;
      background-color: #fff;
      -webkit-text-size-adjust: 100%;
    }
    .container {
      max-width: 800px;
      margin: 0 auto;
      padding: 20px 16px;
    }
    h1 {
      font-size: 24px;
      font-weight: 700;
      margin-bottom: 8px;
      color: #111;
    }
    h2 {
      font-size: 20px;
      font-weight: 600;
      margin-top: 32px;
      margin-bottom: 12px;
      color: #222;
    }
    h3 {
      font-size: 17px;
      font-weight: 600;
      margin-top: 20px;
      margin-bottom: 8px;
      color: #333;
    }
    p {
      margin-bottom: 16px;
    }
    ul {
      margin-bottom: 16px;
      padding-left: 24px;
    }
    li {
      margin-bottom: 8px;
    }
    a {
      color: #007AFF;
      text-decoration: none;
    }
    a:hover {
      text-decoration: underline;
    }
    .effective-date {
      font-size: 14px;
      color: #666;
      margin-bottom: 24px;
    }
    @media (prefers-color-scheme: dark) {
      body {
        background-color: #1c1c1e;
        color: #e5e5e7;
      }
      h1 { color: #f5f5f7; }
      h2 { color: #e5e5e7; }
      h3 { color: #d1d1d6; }
      a { color: #0A84FF; }
      .effective-date { color: #98989d; }
    }''';
}

/// 법적 문서 인덱스 HTML을 생성합니다 (P1-15.5).
///
/// GitHub Pages branch 서빙(`docs/legal/`)의 디렉토리 진입점.
/// 기존 legal-pages 워크플로우의 index 생성 셸 스크립트를 이식했습니다.
String generateLegalIndex({required String appName}) {
  return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$appName — Legal</title>
</head>
<body>
  <h1>$appName — Legal Documents</h1>
  <ul>
    <li><a href="privacy_policy.html">Privacy Policy</a></li>
    <li><a href="terms_of_service.html">Terms of Service</a></li>
  </ul>
</body>
</html>
''';
}
