//
//  Generated code. Do not modify.
//  source: auth.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use loginRequestDescriptor instead')
const LoginRequest$json = {
  '1': 'LoginRequest',
  '2': [
    {'1': 'login_id', '3': 1, '4': 1, '5': 9, '10': 'loginId'},
    {'1': 'password', '3': 2, '4': 1, '5': 9, '10': 'password'},
    {'1': 'role', '3': 3, '4': 1, '5': 9, '10': 'role'},
  ],
};

/// Descriptor for `LoginRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loginRequestDescriptor = $convert.base64Decode(
    'CgxMb2dpblJlcXVlc3QSGQoIbG9naW5faWQYASABKAlSB2xvZ2luSWQSGgoIcGFzc3dvcmQYAi'
    'ABKAlSCHBhc3N3b3JkEhIKBHJvbGUYAyABKAlSBHJvbGU=');

@$core.Deprecated('Use loginResponseDescriptor instead')
const LoginResponse$json = {
  '1': 'LoginResponse',
  '2': [
    {'1': 'token', '3': 1, '4': 1, '5': 9, '10': 'token'},
    {'1': 'user_id', '3': 2, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'success', '3': 3, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 4, '4': 1, '5': 9, '10': 'message'},
    {'1': 'user_profile', '3': 5, '4': 1, '5': 11, '6': '.auth.UserProfile', '10': 'userProfile'},
  ],
};

/// Descriptor for `LoginResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loginResponseDescriptor = $convert.base64Decode(
    'Cg1Mb2dpblJlc3BvbnNlEhQKBXRva2VuGAEgASgJUgV0b2tlbhIXCgd1c2VyX2lkGAIgASgJUg'
    'Z1c2VySWQSGAoHc3VjY2VzcxgDIAEoCFIHc3VjY2VzcxIYCgdtZXNzYWdlGAQgASgJUgdtZXNz'
    'YWdlEjQKDHVzZXJfcHJvZmlsZRgFIAEoCzIRLmF1dGguVXNlclByb2ZpbGVSC3VzZXJQcm9maW'
    'xl');

@$core.Deprecated('Use signupRequestDescriptor instead')
const SignupRequest$json = {
  '1': 'SignupRequest',
  '2': [
    {'1': 'full_name', '3': 1, '4': 1, '5': 9, '10': 'fullName'},
    {'1': 'login_id', '3': 2, '4': 1, '5': 9, '10': 'loginId'},
    {'1': 'password', '3': 3, '4': 1, '5': 9, '10': 'password'},
    {'1': 'branch', '3': 4, '4': 1, '5': 9, '10': 'branch'},
    {'1': 'year', '3': 5, '4': 1, '5': 9, '10': 'year'},
  ],
};

/// Descriptor for `SignupRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signupRequestDescriptor = $convert.base64Decode(
    'Cg1TaWdudXBSZXF1ZXN0EhsKCWZ1bGxfbmFtZRgBIAEoCVIIZnVsbE5hbWUSGQoIbG9naW5faW'
    'QYAiABKAlSB2xvZ2luSWQSGgoIcGFzc3dvcmQYAyABKAlSCHBhc3N3b3JkEhYKBmJyYW5jaBgE'
    'IAEoCVIGYnJhbmNoEhIKBHllYXIYBSABKAlSBHllYXI=');

@$core.Deprecated('Use signupResponseDescriptor instead')
const SignupResponse$json = {
  '1': 'SignupResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'user_id', '3': 3, '4': 1, '5': 9, '10': 'userId'},
  ],
};

/// Descriptor for `SignupResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List signupResponseDescriptor = $convert.base64Decode(
    'Cg5TaWdudXBSZXNwb25zZRIYCgdzdWNjZXNzGAEgASgIUgdzdWNjZXNzEhgKB21lc3NhZ2UYAi'
    'ABKAlSB21lc3NhZ2USFwoHdXNlcl9pZBgDIAEoCVIGdXNlcklk');

@$core.Deprecated('Use userProfileDescriptor instead')
const UserProfile$json = {
  '1': 'UserProfile',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'role', '3': 2, '4': 1, '5': 9, '10': 'role'},
    {'1': 'branch', '3': 3, '4': 1, '5': 9, '10': 'branch'},
    {'1': 'year', '3': 4, '4': 1, '5': 9, '10': 'year'},
    {'1': 'semester', '3': 5, '4': 1, '5': 9, '10': 'semester'},
    {'1': 'batch_no', '3': 6, '4': 1, '5': 9, '10': 'batchNo'},
    {'1': 'login_id', '3': 7, '4': 1, '5': 9, '10': 'loginId'},
  ],
};

/// Descriptor for `UserProfile`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userProfileDescriptor = $convert.base64Decode(
    'CgtVc2VyUHJvZmlsZRISCgRuYW1lGAEgASgJUgRuYW1lEhIKBHJvbGUYAiABKAlSBHJvbGUSFg'
    'oGYnJhbmNoGAMgASgJUgZicmFuY2gSEgoEeWVhchgEIAEoCVIEeWVhchIaCghzZW1lc3RlchgF'
    'IAEoCVIIc2VtZXN0ZXISGQoIYmF0Y2hfbm8YBiABKAlSB2JhdGNoTm8SGQoIbG9naW5faWQYBy'
    'ABKAlSB2xvZ2luSWQ=');

