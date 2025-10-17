"use strict";
/**
 * 🔒 SECURE: Server-side validation helpers for subscription operations
 *
 * This module provides:
 * - Comprehensive input validation for all subscription operations
 * - Data sanitization to prevent injection attacks
 * - Business rule validation and enforcement
 * - Security checks and rate limiting
 * - Audit logging for all validation operations
 */
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || function (mod) {
    if (mod && mod.__esModule) return mod;
    var result = {};
    if (mod != null) for (var k in mod) if (k !== "default" && Object.prototype.hasOwnProperty.call(mod, k)) __createBinding(result, mod, k);
    __setModuleDefault(result, mod);
    return result;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ValidationAuditLogger = exports.validateFeatureAccess = exports.validateSubscriptionCreation = exports.SubscriptionValidator = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
/**
 * Main subscription validation class
 */
class SubscriptionValidator {
    /**
     * Validate subscription creation request
     */
    static async validateSubscriptionCreation(data, context) {
        const validationId = `sub_create_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
        this.logger.info('Starting subscription creation validation', {
            validationId,
            userId: context.auth?.uid,
            hasData: !!data,
        });
        const errors = [];
        const sanitizedData = {};
        try {
            // Validate authentication
            if (!context.auth?.uid) {
                errors.push({
                    field: 'auth',
                    code: 'AUTH_REQUIRED',
                    message: 'User must be authenticated',
                    severity: 'error'
                });
                return { isValid: false, errors };
            }
            // Validate user ID
            const userIdResult = this.validateUserId(data?.userId, context.auth.uid);
            if (!userIdResult.isValid) {
                errors.push(...userIdResult.errors);
            }
            else {
                sanitizedData.userId = userIdResult.sanitizedData;
            }
            // Validate user type
            const userTypeResult = this.validateUserType(data?.userType);
            if (!userTypeResult.isValid) {
                errors.push(...userTypeResult.errors);
            }
            else {
                sanitizedData.userType = userTypeResult.sanitizedData;
            }
            // Validate subscription tier
            const tierResult = this.validateSubscriptionTier(data?.tier);
            if (!tierResult.isValid) {
                errors.push(...tierResult.errors);
            }
            else {
                sanitizedData.tier = tierResult.sanitizedData;
            }
            // Validate optional Stripe fields
            if (data?.stripeCustomerId) {
                const customerIdResult = this.validateStripeCustomerId(data.stripeCustomerId);
                if (!customerIdResult.isValid) {
                    errors.push(...customerIdResult.errors);
                }
                else {
                    sanitizedData.stripeCustomerId = customerIdResult.sanitizedData;
                }
            }
            if (data?.stripePriceId) {
                const priceIdResult = this.validateStripePriceId(data.stripePriceId);
                if (!priceIdResult.isValid) {
                    errors.push(...priceIdResult.errors);
                }
                else {
                    sanitizedData.stripePriceId = priceIdResult.sanitizedData;
                }
            }
            if (data?.stripeSubscriptionId) {
                const subscriptionIdResult = this.validateStripeSubscriptionId(data.stripeSubscriptionId);
                if (!subscriptionIdResult.isValid) {
                    errors.push(...subscriptionIdResult.errors);
                }
                else {
                    sanitizedData.stripeSubscriptionId = subscriptionIdResult.sanitizedData;
                }
            }
            // Validate metadata
            const metadataResult = this.validateMetadata(data?.metadata);
            if (!metadataResult.isValid) {
                errors.push(...metadataResult.errors);
            }
            else {
                sanitizedData.metadata = metadataResult.sanitizedData;
            }
            // Business rule validations
            if (errors.length === 0) {
                const businessRulesResult = await this.validateBusinessRules(sanitizedData, context);
                if (!businessRulesResult.isValid) {
                    errors.push(...businessRulesResult.errors);
                }
            }
            const isValid = errors.filter(e => e.severity === 'error').length === 0;
            this.logger.info('Subscription creation validation completed', {
                validationId,
                isValid,
                errorCount: errors.length,
                warningCount: errors.filter(e => e.severity === 'warning').length,
            });
            return {
                isValid,
                errors,
                sanitizedData: isValid ? sanitizedData : undefined,
            };
        }
        catch (error) {
            this.logger.error('Subscription validation error', {
                validationId,
                error: error instanceof Error ? error.message : String(error),
                stack: error instanceof Error ? error.stack : undefined,
            });
            return {
                isValid: false,
                errors: [{
                        field: 'system',
                        code: 'VALIDATION_ERROR',
                        message: 'Internal validation error occurred',
                        severity: 'error'
                    }]
            };
        }
    }
    /**
     * Validate feature access request
     */
    static async validateFeatureAccess(data, context) {
        const validationId = `feat_access_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
        this.logger.info('Starting feature access validation', {
            validationId,
            userId: context.auth?.uid,
            featureName: data?.featureName,
        });
        const errors = [];
        const sanitizedData = {};
        try {
            // Validate authentication
            if (!context.auth?.uid) {
                errors.push({
                    field: 'auth',
                    code: 'AUTH_REQUIRED',
                    message: 'User must be authenticated',
                    severity: 'error'
                });
                return { isValid: false, errors };
            }
            // Validate user ID
            const userIdResult = this.validateUserId(data?.userId, context.auth.uid);
            if (!userIdResult.isValid) {
                errors.push(...userIdResult.errors);
            }
            else {
                sanitizedData.userId = userIdResult.sanitizedData;
            }
            // Validate feature name
            const featureResult = this.validateFeatureName(data?.featureName);
            if (!featureResult.isValid) {
                errors.push(...featureResult.errors);
            }
            else {
                sanitizedData.featureName = featureResult.sanitizedData;
            }
            // Rate limiting check
            const rateLimitResult = await this.checkRateLimit(context.auth.uid, 'feature_access');
            if (!rateLimitResult.isValid) {
                errors.push(...rateLimitResult.errors);
            }
            const isValid = errors.filter(e => e.severity === 'error').length === 0;
            this.logger.info('Feature access validation completed', {
                validationId,
                isValid,
                errorCount: errors.length,
            });
            return {
                isValid,
                errors,
                sanitizedData: isValid ? sanitizedData : undefined,
            };
        }
        catch (error) {
            this.logger.error('Feature access validation error', {
                validationId,
                error: error instanceof Error ? error.message : String(error),
                stack: error instanceof Error ? error.stack : undefined,
            });
            return {
                isValid: false,
                errors: [{
                        field: 'system',
                        code: 'VALIDATION_ERROR',
                        message: 'Internal validation error occurred',
                        severity: 'error'
                    }]
            };
        }
    }
    /**
     * Validate user ID and ensure it matches authenticated user
     */
    static validateUserId(userId, authUserId) {
        const errors = [];
        if (!userId || typeof userId !== 'string') {
            errors.push({
                field: 'userId',
                code: 'USER_ID_REQUIRED',
                message: 'User ID is required and must be a string',
                severity: 'error'
            });
            return { isValid: false, errors };
        }
        const sanitized = userId.trim();
        // Check format (Firebase Auth UID format)
        if (!/^[a-zA-Z0-9]{28}$/.test(sanitized)) {
            errors.push({
                field: 'userId',
                code: 'USER_ID_INVALID_FORMAT',
                message: 'Invalid user ID format',
                severity: 'error'
            });
        }
        // Ensure user ID matches authenticated user
        if (sanitized !== authUserId) {
            errors.push({
                field: 'userId',
                code: 'USER_ID_MISMATCH',
                message: 'User ID must match authenticated user',
                severity: 'error'
            });
        }
        // Check for suspicious patterns
        if (this.containsSuspiciousChars(sanitized)) {
            errors.push({
                field: 'userId',
                code: 'USER_ID_SUSPICIOUS',
                message: 'User ID contains suspicious characters',
                severity: 'error'
            });
        }
        return {
            isValid: errors.length === 0,
            errors,
            sanitizedData: sanitized,
        };
    }
    /**
     * Validate user type
     */
    static validateUserType(userType) {
        const errors = [];
        if (!userType || typeof userType !== 'string') {
            errors.push({
                field: 'userType',
                code: 'USER_TYPE_REQUIRED',
                message: 'User type is required and must be a string',
                severity: 'error'
            });
            return { isValid: false, errors };
        }
        const sanitized = userType.trim().toLowerCase();
        const validUserTypes = ['shopper', 'vendor', 'market_organizer'];
        if (!validUserTypes.includes(sanitized)) {
            errors.push({
                field: 'userType',
                code: 'USER_TYPE_INVALID',
                message: `Invalid user type. Must be one of: ${validUserTypes.join(', ')}`,
                severity: 'error'
            });
        }
        return {
            isValid: errors.length === 0,
            errors,
            sanitizedData: sanitized,
        };
    }
    /**
     * Validate subscription tier
     */
    static validateSubscriptionTier(tier) {
        const errors = [];
        if (!tier || typeof tier !== 'string') {
            errors.push({
                field: 'tier',
                code: 'TIER_REQUIRED',
                message: 'Subscription tier is required and must be a string',
                severity: 'error'
            });
            return { isValid: false, errors };
        }
        const sanitized = tier.trim();
        const validTiers = ['free', 'shopperPro', 'vendorPro', 'marketOrganizerPro', 'enterprise'];
        if (!validTiers.includes(sanitized)) {
            errors.push({
                field: 'tier',
                code: 'TIER_INVALID',
                message: `Invalid subscription tier. Must be one of: ${validTiers.join(', ')}`,
                severity: 'error'
            });
        }
        return {
            isValid: errors.length === 0,
            errors,
            sanitizedData: sanitized,
        };
    }
    /**
     * Validate Stripe customer ID
     */
    static validateStripeCustomerId(customerId) {
        const errors = [];
        if (typeof customerId !== 'string') {
            errors.push({
                field: 'stripeCustomerId',
                code: 'CUSTOMER_ID_INVALID_TYPE',
                message: 'Stripe customer ID must be a string',
                severity: 'error'
            });
            return { isValid: false, errors };
        }
        const sanitized = customerId.trim();
        if (!sanitized.startsWith('cus_')) {
            errors.push({
                field: 'stripeCustomerId',
                code: 'CUSTOMER_ID_INVALID_FORMAT',
                message: 'Stripe customer ID must start with "cus_"',
                severity: 'error'
            });
        }
        if (!/^cus_[a-zA-Z0-9_]+$/.test(sanitized)) {
            errors.push({
                field: 'stripeCustomerId',
                code: 'CUSTOMER_ID_INVALID_CHARS',
                message: 'Stripe customer ID contains invalid characters',
                severity: 'error'
            });
        }
        return {
            isValid: errors.length === 0,
            errors,
            sanitizedData: sanitized,
        };
    }
    /**
     * Validate Stripe price ID
     */
    static validateStripePriceId(priceId) {
        const errors = [];
        if (typeof priceId !== 'string') {
            errors.push({
                field: 'stripePriceId',
                code: 'PRICE_ID_INVALID_TYPE',
                message: 'Stripe price ID must be a string',
                severity: 'error'
            });
            return { isValid: false, errors };
        }
        const sanitized = priceId.trim();
        if (!sanitized.startsWith('price_')) {
            errors.push({
                field: 'stripePriceId',
                code: 'PRICE_ID_INVALID_FORMAT',
                message: 'Stripe price ID must start with "price_"',
                severity: 'error'
            });
        }
        if (!/^price_[a-zA-Z0-9_]+$/.test(sanitized)) {
            errors.push({
                field: 'stripePriceId',
                code: 'PRICE_ID_INVALID_CHARS',
                message: 'Stripe price ID contains invalid characters',
                severity: 'error'
            });
        }
        if (sanitized.length < 8 || sanitized.length > 100) {
            errors.push({
                field: 'stripePriceId',
                code: 'PRICE_ID_INVALID_LENGTH',
                message: 'Stripe price ID must be between 8 and 100 characters',
                severity: 'error'
            });
        }
        return {
            isValid: errors.length === 0,
            errors,
            sanitizedData: sanitized,
        };
    }
    /**
     * Validate Stripe subscription ID
     */
    static validateStripeSubscriptionId(subscriptionId) {
        const errors = [];
        if (typeof subscriptionId !== 'string') {
            errors.push({
                field: 'stripeSubscriptionId',
                code: 'SUBSCRIPTION_ID_INVALID_TYPE',
                message: 'Stripe subscription ID must be a string',
                severity: 'error'
            });
            return { isValid: false, errors };
        }
        const sanitized = subscriptionId.trim();
        if (!sanitized.startsWith('sub_')) {
            errors.push({
                field: 'stripeSubscriptionId',
                code: 'SUBSCRIPTION_ID_INVALID_FORMAT',
                message: 'Stripe subscription ID must start with "sub_"',
                severity: 'error'
            });
        }
        if (!/^sub_[a-zA-Z0-9_]+$/.test(sanitized)) {
            errors.push({
                field: 'stripeSubscriptionId',
                code: 'SUBSCRIPTION_ID_INVALID_CHARS',
                message: 'Stripe subscription ID contains invalid characters',
                severity: 'error'
            });
        }
        return {
            isValid: errors.length === 0,
            errors,
            sanitizedData: sanitized,
        };
    }
    /**
     * Validate feature name
     */
    static validateFeatureName(featureName) {
        const errors = [];
        if (!featureName || typeof featureName !== 'string') {
            errors.push({
                field: 'featureName',
                code: 'FEATURE_NAME_REQUIRED',
                message: 'Feature name is required and must be a string',
                severity: 'error'
            });
            return { isValid: false, errors };
        }
        const sanitized = featureName.trim().toLowerCase();
        // Check format (snake_case)
        if (!/^[a-z][a-z0-9_]*[a-z0-9]$|^[a-z]$/.test(sanitized)) {
            errors.push({
                field: 'featureName',
                code: 'FEATURE_NAME_INVALID_FORMAT',
                message: 'Feature name must use snake_case format',
                severity: 'error'
            });
        }
        if (sanitized.length > 50) {
            errors.push({
                field: 'featureName',
                code: 'FEATURE_NAME_TOO_LONG',
                message: 'Feature name must be less than 50 characters',
                severity: 'error'
            });
        }
        return {
            isValid: errors.length === 0,
            errors,
            sanitizedData: sanitized,
        };
    }
    /**
     * Validate metadata
     */
    static validateMetadata(metadata) {
        const errors = [];
        if (!metadata) {
            return { isValid: true, errors: [], sanitizedData: {} };
        }
        if (typeof metadata !== 'object' || Array.isArray(metadata)) {
            errors.push({
                field: 'metadata',
                code: 'METADATA_INVALID_TYPE',
                message: 'Metadata must be an object',
                severity: 'error'
            });
            return { isValid: false, errors };
        }
        const sanitizedMetadata = {};
        // Check total size
        const metadataString = JSON.stringify(metadata);
        if (metadataString.length > 5000) {
            errors.push({
                field: 'metadata',
                code: 'METADATA_TOO_LARGE',
                message: 'Metadata is too large (max 5000 characters)',
                severity: 'error'
            });
            return { isValid: false, errors };
        }
        // Validate individual key-value pairs
        for (const [key, value] of Object.entries(metadata)) {
            // Validate key
            if (!key || key.length > 100) {
                errors.push({
                    field: 'metadata',
                    code: 'METADATA_KEY_INVALID',
                    message: `Invalid metadata key: ${key}`,
                    severity: 'error'
                });
                continue;
            }
            if (!/^[a-zA-Z0-9_.-]+$/.test(key)) {
                errors.push({
                    field: 'metadata',
                    code: 'METADATA_KEY_INVALID_CHARS',
                    message: `Metadata key contains invalid characters: ${key}`,
                    severity: 'error'
                });
                continue;
            }
            // Sanitize value
            const sanitizedValue = this.sanitizeMetadataValue(value);
            if (sanitizedValue === null) {
                errors.push({
                    field: 'metadata',
                    code: 'METADATA_VALUE_INVALID',
                    message: `Invalid metadata value for key: ${key}`,
                    severity: 'error'
                });
                continue;
            }
            sanitizedMetadata[key] = sanitizedValue;
        }
        return {
            isValid: errors.length === 0,
            errors,
            sanitizedData: sanitizedMetadata,
        };
    }
    /**
     * Validate business rules
     */
    static async validateBusinessRules(data, context) {
        const errors = [];
        try {
            // Check if user already has an active subscription
            const existingSubscription = await admin.firestore()
                .collection('user_subscriptions')
                .where('userId', '==', data.userId)
                .where('status', '==', 'active')
                .limit(1)
                .get();
            if (!existingSubscription.empty && data.tier !== 'free') {
                errors.push({
                    field: 'subscription',
                    code: 'SUBSCRIPTION_ALREADY_EXISTS',
                    message: 'User already has an active subscription',
                    severity: 'warning'
                });
            }
            // Validate tier compatibility with user type
            const validTierForUserType = this.isValidTierForUserType(data.tier, data.userType);
            if (!validTierForUserType) {
                errors.push({
                    field: 'tier',
                    code: 'TIER_USER_TYPE_MISMATCH',
                    message: `Tier ${data.tier} is not valid for user type ${data.userType}`,
                    severity: 'error'
                });
            }
            // Rate limiting - check subscription creation frequency
            const recentSubscriptions = await admin.firestore()
                .collection('user_subscriptions')
                .where('userId', '==', data.userId)
                .where('createdAt', '>=', new Date(Date.now() - 24 * 60 * 60 * 1000)) // Last 24 hours
                .get();
            if (recentSubscriptions.size > 5) {
                errors.push({
                    field: 'rateLimit',
                    code: 'RATE_LIMIT_EXCEEDED',
                    message: 'Too many subscription operations in the last 24 hours',
                    severity: 'error'
                });
            }
        }
        catch (error) {
            this.logger.error('Business rules validation error', {
                error: error instanceof Error ? error.message : String(error),
                userId: data.userId,
            });
            errors.push({
                field: 'system',
                code: 'BUSINESS_RULES_ERROR',
                message: 'Error validating business rules',
                severity: 'error'
            });
        }
        return {
            isValid: errors.filter(e => e.severity === 'error').length === 0,
            errors,
        };
    }
    /**
     * Check rate limits for operations
     */
    static async checkRateLimit(userId, operation) {
        const errors = [];
        try {
            // Simple rate limiting using Firestore
            const rateLimitDoc = admin.firestore()
                .collection('rate_limits')
                .doc(`${userId}_${operation}`);
            const rateLimitData = await rateLimitDoc.get();
            const now = Date.now();
            const windowMs = 60 * 1000; // 1 minute window
            const maxRequests = 100; // Max requests per window
            if (rateLimitData.exists) {
                const data = rateLimitData.data();
                const windowStart = data?.windowStart || 0;
                const requestCount = data?.requestCount || 0;
                if (now - windowStart < windowMs) {
                    if (requestCount >= maxRequests) {
                        errors.push({
                            field: 'rateLimit',
                            code: 'RATE_LIMIT_EXCEEDED',
                            message: 'Too many requests. Please wait before trying again.',
                            severity: 'error'
                        });
                    }
                    else {
                        // Increment counter
                        await rateLimitDoc.update({
                            requestCount: requestCount + 1,
                        });
                    }
                }
                else {
                    // New window
                    await rateLimitDoc.set({
                        windowStart: now,
                        requestCount: 1,
                    });
                }
            }
            else {
                // First request
                await rateLimitDoc.set({
                    windowStart: now,
                    requestCount: 1,
                });
            }
        }
        catch (error) {
            this.logger.warn('Rate limit check failed', {
                error: error instanceof Error ? error.message : String(error),
                userId,
                operation,
            });
            // Don't fail validation due to rate limit check errors
        }
        return {
            isValid: errors.length === 0,
            errors,
        };
    }
    /**
     * Helper method to check for suspicious characters
     */
    static containsSuspiciousChars(input) {
        const suspiciousPatterns = [
            /<[^>]*>/g,
            /javascript:/gi,
            /on\w+\s*=/gi,
            /(union|select|insert|update|delete|drop)/gi,
            /[\x00-\x08\x0B-\x0C\x0E-\x1F\x7F]/g, // Control characters
        ];
        return suspiciousPatterns.some(pattern => pattern.test(input));
    }
    /**
     * Sanitize metadata value
     */
    static sanitizeMetadataValue(value) {
        if (typeof value === 'string') {
            const sanitized = value.trim();
            if (sanitized.length > 500) {
                return sanitized.substring(0, 500); // Truncate long strings
            }
            return sanitized;
        }
        else if (typeof value === 'number' || typeof value === 'boolean') {
            return value;
        }
        else if (value === null || value === undefined) {
            return null;
        }
        // Invalid type
        return null;
    }
    /**
     * Check if tier is valid for user type
     */
    static isValidTierForUserType(tier, userType) {
        const validCombinations = {
            shopper: ['free', 'shopperPro'],
            vendor: ['free', 'vendorPro', 'enterprise'],
            market_organizer: ['free', 'marketOrganizerPro', 'enterprise'],
        };
        return validCombinations[userType]?.includes(tier) || false;
    }
}
exports.SubscriptionValidator = SubscriptionValidator;
SubscriptionValidator.logger = functions.logger;
/**
 * Cloud Function wrapper for subscription validation
 */
exports.validateSubscriptionCreation = functions.https.onCall(async (data, context) => {
    return SubscriptionValidator.validateSubscriptionCreation(data, context);
});
exports.validateFeatureAccess = functions.https.onCall(async (data, context) => {
    return SubscriptionValidator.validateFeatureAccess(data, context);
});
/**
 * Audit logging for validation events
 */
class ValidationAuditLogger {
    static async logValidationEvent(operation, userId, result, metadata = {}) {
        try {
            const auditEntry = {
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                operation,
                userId,
                validationResult: {
                    isValid: result.isValid,
                    errorCount: result.errors.length,
                    errorCodes: result.errors.map(e => e.code),
                },
                metadata,
            };
            await admin.firestore()
                .collection('validation_audit')
                .add(auditEntry);
        }
        catch (error) {
            this.logger.error('Failed to log validation audit', {
                error: error instanceof Error ? error.message : String(error),
                operation,
                userId,
            });
        }
    }
}
exports.ValidationAuditLogger = ValidationAuditLogger;
ValidationAuditLogger.logger = functions.logger;
//# sourceMappingURL=subscription-validation.js.map