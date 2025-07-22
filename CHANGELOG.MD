# 0.12.0
* FI-4182 Remove inferno@groups.mitre.org email from gemspec by @arscan in https://github.com/inferno-framework/subscriptions-test-kit/pull/34

# 0.11.3
* FI-4144: Requirement clean for PAS by @karlnaden in https://github.com/inferno-framework/subscriptions-test-kit/pull/32

# 0.11.2

* FI-4141: Requirements Conversion by @karlnaden in https://github.com/inferno-framework/subscriptions-test-kit/pull/29
* FI-4141: Requirements Conversion Update by @karlnaden in https://github.com/inferno-framework/subscriptions-test-kit/pull/30

# 0.11.1

* FI-3652: Allow nonconformant subscription and capability statement by @tstrass in https://github.com/inferno-framework/subscriptions-test-kit/pull/27


# 0.11.0
### Breaking Change
This release updates the FHIR Subscriptions Test Kit to use AuthInfo rather than
OAuthCredentials for storing auth information. As a result of this change, any
test kits which rely on this test kit will need to be updated to use AuthInfo
rather than OAuthCredentials inputs.

* FI-3746: Use AuthInfo by @Jammjammjamm in https://github.com/inferno-framework/subscriptions-test-kit/pull/23

## 0.10.1

* FI-3011: Rest hook notification validation by @dclark43 in https://github.com/inferno-framework/subscriptions-test-kit/pull/8
* Fix test kit title and description by @tstrass in https://github.com/inferno-framework/subscriptions-test-kit/pull/22
* FI-3625: Statically define Suite ID in URLs by @tstrass in https://github.com/inferno-framework/subscriptions-test-kit/pull/24

## 0.10.0

### Breaking changes by @vanessuniq in https://github.com/inferno-framework/subscriptions-test-kit/pull/19:
* Ruby Version Update: Upgraded Ruby to 3.3.6.
* Inferno Core Update: Bumped to version 0.6.
* Gemspec Updates:
  * Switched to git for specifying files.
  * Added presets to the gem package.
  * Updated any test kit dependencies
* Test Kit Metadata: Implemented Test Kit metadata for Inferno Platform.
* Environment Updates: Updated Ruby version in the Dockerfile and GitHub Actions workflow.

### Additional changes:
* Fix subscription status endpoint bug by @tstrass in https://github.com/inferno-framework/subscriptions-test-kit/pull/21
* FI-3243: User-experience Improvements by @karlnaden in https://github.com/inferno-framework/subscriptions-test-kit/pull/18

## 0.9.4

* Correctly add authorization header to Subscription.channel.header by @karlnaden in https://github.com/inferno-framework/subscriptions-test-kit/pull/14
* Client Test Notification Generation Enhancements by @karlnaden in https://github.com/inferno-framework/subscriptions-test-kit/pull/15
* FI-3010: Split out Subscription Rejection tests by @ChristineDuong in https://github.com/inferno-framework/subscriptions-test-kit/pull/7
* FI-3475: Unit test improvements by @Jammjammjamm in https://github.com/inferno-framework/subscriptions-test-kit/pull/13
* Fi 3007 - Validate subcription criteria by @nhcady in https://github.com/inferno-framework/subscriptions-test-kit/pull/5

## 0.9.3

* put requirements coverage in sync with id change by @karlnaden in https://github.com/inferno-framework/subscriptions-test-kit/pull/3
* Fi-3237: Rubocop and Continuous Integration by @tstrass in https://github.com/inferno-framework/subscriptions-test-kit/pull/4
* FI-3410: Update inferno core requirement by @Jammjammjamm in https://github.com/inferno-framework/subscriptions-test-kit/pull/9
* Updated typo in text by @nhcady in https://github.com/inferno-framework/subscriptions-test-kit/pull/6

## v0.9.2

* Shorten group and test ids to prevent errors when running on postgres such as on inferno.healthit.gov.

## v0.9.1

* Move roo gem to a development dependency and update the version

## v0.9.0

* Initial public release of the Inferno Subscriptions Test Kit.
