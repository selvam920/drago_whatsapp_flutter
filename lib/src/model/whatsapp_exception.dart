enum WhatsappExceptionType {
  failedToConnect,
  unknown,
  connectionFailed,
  unAuthorized,
  inValidContact,
  clientNotConnected,
  clientErrorException,
  timeout,
  loginFailed,
}

class WhatsappException implements Exception {
  final String message;
  final WhatsappExceptionType exceptionType;
  final String? details;

  const WhatsappException({
    this.message = "Something went wrong",
    this.exceptionType = WhatsappExceptionType.unknown,
    this.details,
  });

  @override
  String toString() {
    String out = "WhatsappException [$exceptionType]: $message";
    if (details != null) out += " (Details: $details)";
    return out;
  }
}
