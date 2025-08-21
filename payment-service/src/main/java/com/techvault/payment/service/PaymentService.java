package com.techvault.payment.service;

import com.techvault.payment.dto.PaymentRequest;
import com.techvault.payment.dto.PaymentResponse;
import com.techvault.payment.model.Payment;
import com.techvault.payment.model.PaymentStatus;
import com.techvault.payment.repository.PaymentRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@Transactional
public class PaymentService {

    @Autowired
    private PaymentRepository paymentRepository;

    public PaymentResponse processPayment(PaymentRequest request) {
        try {
            // Create payment record
            Payment payment = new Payment(
                request.getOrderId(),
                request.getUserId(),
                request.getAmount(),
                request.getPaymentMethod()
            );
            
            payment.setCurrency(request.getCurrency());
            payment.setStatus(PaymentStatus.PROCESSING);
            
            // Save payment
            payment = paymentRepository.save(payment);
            
            // Simulate payment processing
            boolean paymentSuccess = simulatePaymentProcessing(request);
            
            if (paymentSuccess) {
                payment.setStatus(PaymentStatus.COMPLETED);
                payment.setTransactionId(generateTransactionId());
            } else {
                payment.setStatus(PaymentStatus.FAILED);
            }
            
            payment = paymentRepository.save(payment);
            
            return convertToResponse(payment, 
                paymentSuccess ? "Payment processed successfully" : "Payment failed");
                
        } catch (Exception e) {
            throw new RuntimeException("Payment processing failed: " + e.getMessage());
        }
    }

    public List<PaymentResponse> getPaymentsByUserId(Long userId) {
        List<Payment> payments = paymentRepository.findByUserId(userId);
        return payments.stream()
                .map(this::convertToResponse)
                .collect(Collectors.toList());
    }

    public Optional<PaymentResponse> getPaymentByOrderId(Long orderId) {
        return paymentRepository.findByOrderId(orderId)
                .map(this::convertToResponse);
    }

    public Optional<PaymentResponse> getPaymentById(Long paymentId) {
        return paymentRepository.findById(paymentId)
                .map(this::convertToResponse);
    }

    public PaymentResponse refundPayment(Long paymentId) {
        Optional<Payment> paymentOpt = paymentRepository.findById(paymentId);
        
        if (paymentOpt.isEmpty()) {
            throw new RuntimeException("Payment not found");
        }
        
        Payment payment = paymentOpt.get();
        
        if (payment.getStatus() != PaymentStatus.COMPLETED) {
            throw new RuntimeException("Can only refund completed payments");
        }
        
        // Simulate refund processing
        payment.setStatus(PaymentStatus.REFUNDED);
        payment = paymentRepository.save(payment);
        
        return convertToResponse(payment, "Payment refunded successfully");
    }

    private boolean simulatePaymentProcessing(PaymentRequest request) {
        // Simulate payment processing logic
        // In a real implementation, this would integrate with payment gateways
        
        // For demo purposes, fail payments with amount > 1000
        return request.getAmount().doubleValue() <= 1000.0;
    }

    private String generateTransactionId() {
        return "TXN_" + UUID.randomUUID().toString().replace("-", "").substring(0, 12).toUpperCase();
    }

    private PaymentResponse convertToResponse(Payment payment) {
        return convertToResponse(payment, null);
    }

    private PaymentResponse convertToResponse(Payment payment, String message) {
        PaymentResponse response = new PaymentResponse(
            payment.getId(),
            payment.getOrderId(),
            payment.getUserId(),
            payment.getAmount(),
            payment.getCurrency(),
            payment.getStatus(),
            payment.getPaymentMethod(),
            payment.getTransactionId(),
            payment.getCreatedAt(),
            payment.getUpdatedAt()
        );
        
        if (message != null) {
            response.setMessage(message);
        }
        
        return response;
    }
}
