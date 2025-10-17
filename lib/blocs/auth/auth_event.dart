import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthStarted extends AuthEvent {}

class AuthUserChanged extends AuthEvent {
  final dynamic user;
  
  const AuthUserChanged(this.user);
  
  @override
  List<Object?> get props => [user];
}

class LoginEvent extends AuthEvent {
  final String email;
  final String password;
  
  const LoginEvent({required this.email, required this.password});
  
  @override
  List<Object> get props => [email, password];
}

class SignUpEvent extends AuthEvent {
  final String name;
  final String email;
  final String password;
  final String userType;
  
  const SignUpEvent({
    required this.name,
    required this.email,
    required this.password,
    required this.userType,
  });
  
  @override
  List<Object> get props => [name, email, password, userType];
}

class LogoutEvent extends AuthEvent {}

// Phone Authentication Events
class PhoneSignInRequestedEvent extends AuthEvent {
  final String phoneNumber;
  final String? userType;
  final String? displayName;
  
  const PhoneSignInRequestedEvent({
    required this.phoneNumber,
    this.userType,
    this.displayName,
  });
  
  @override
  List<Object?> get props => [phoneNumber, userType, displayName];
}

class PhoneCodeSentEvent extends AuthEvent {
  final String verificationId;
  final int? resendToken;
  
  const PhoneCodeSentEvent({
    required this.verificationId,
    this.resendToken,
  });
  
  @override
  List<Object?> get props => [verificationId, resendToken];
}

class PhoneVerificationCompletedEvent extends AuthEvent {
  final dynamic credential;
  
  const PhoneVerificationCompletedEvent({required this.credential});
  
  @override
  List<Object?> get props => [credential];
}

class PhoneVerificationFailedEvent extends AuthEvent {
  final String error;
  
  const PhoneVerificationFailedEvent({required this.error});
  
  @override
  List<Object?> get props => [error];
}

class VerifyPhoneCodeEvent extends AuthEvent {
  final String verificationId;
  final String smsCode;
  final String? userType;
  final String? displayName;
  
  const VerifyPhoneCodeEvent({
    required this.verificationId,
    required this.smsCode,
    this.userType,
    this.displayName,
  });
  
  @override
  List<Object?> get props => [verificationId, smsCode, userType, displayName];
}

class ResendPhoneCodeEvent extends AuthEvent {
  final String phoneNumber;
  final int? resendToken;
  
  const ResendPhoneCodeEvent({
    required this.phoneNumber,
    this.resendToken,
  });
  
  @override
  List<Object?> get props => [phoneNumber, resendToken];
}

class LinkPhoneNumberEvent extends AuthEvent {
  final String phoneNumber;

  const LinkPhoneNumberEvent({required this.phoneNumber});

  @override
  List<Object?> get props => [phoneNumber];
}

class ForgotPasswordEvent extends AuthEvent {
  final String email;
  
  const ForgotPasswordEvent({required this.email});
  
  @override
  List<Object> get props => [email];
}

class SendEmailVerificationEvent extends AuthEvent {}

class ReloadUserEvent extends AuthEvent {}

// Biometric Authentication Events
class BiometricAuthRequestedEvent extends AuthEvent {
  final String userType;
  
  const BiometricAuthRequestedEvent({required this.userType});
  
  @override
  List<Object> get props => [userType];
}

class SaveBiometricCredentialsEvent extends AuthEvent {
  final String email;
  final String password;
  final String userType;
  final String? userId;
  
  const SaveBiometricCredentialsEvent({
    required this.email,
    required this.password,
    required this.userType,
    this.userId,
  });
  
  @override
  List<Object?> get props => [email, password, userType, userId];
}

class EnableBiometricAuthEvent extends AuthEvent {
  final bool enabled;
  
  const EnableBiometricAuthEvent({required this.enabled});
  
  @override
  List<Object> get props => [enabled];
}

class ClearBiometricCredentialsEvent extends AuthEvent {}