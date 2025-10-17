import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/shared/models/user_profile.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {
  final String? message;
  
  const AuthLoading({this.message});
  
  @override
  List<Object?> get props => [message];
}

class Authenticated extends AuthState {
  final User user;
  final String userType;
  final UserProfile? userProfile;
  
  const Authenticated({
    required this.user, 
    required this.userType,
    this.userProfile,
  });
  
  @override
  List<Object?> get props => [user, userType, userProfile];
}

class Unauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  final String? errorCode;
  
  const AuthError({required this.message, this.errorCode});
  
  @override
  List<Object?> get props => [message, errorCode];
}

class PasswordResetSent extends AuthState {
  final String email;
  
  const PasswordResetSent({required this.email});
  
  @override
  List<Object> get props => [email];
}

class EmailVerificationSent extends AuthState {}

class EmailVerificationRequired extends AuthState {
  final User user;
  
  const EmailVerificationRequired({required this.user});
  
  @override
  List<Object> get props => [user];
}

// Phone Authentication States
class PhoneAuthInProgress extends AuthState {
  final String message;
  
  const PhoneAuthInProgress({required this.message});
  
  @override
  List<Object> get props => [message];
}

class PhoneAuthCodeSent extends AuthState {
  final String verificationId;
  final int? resendToken;
  final String phoneNumber;
  
  const PhoneAuthCodeSent({
    required this.verificationId,
    this.resendToken,
    required this.phoneNumber,
  });
  
  @override
  List<Object?> get props => [verificationId, resendToken, phoneNumber];
}

class PhoneAuthError extends AuthState {
  final String message;
  
  const PhoneAuthError({required this.message});
  
  @override
  List<Object> get props => [message];
}

class PhoneAuthTimeout extends AuthState {
  final String verificationId;
  
  const PhoneAuthTimeout({required this.verificationId});
  
  @override
  List<Object> get props => [verificationId];
}

class AuthSuccess extends AuthState {
  final String message;
  
  const AuthSuccess({required this.message});
  
  @override
  List<Object> get props => [message];
}