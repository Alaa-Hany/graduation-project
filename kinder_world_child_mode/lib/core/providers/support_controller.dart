import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinder_world/app.dart';
import 'package:kinder_world/core/models/support_ticket_record.dart';
import 'package:kinder_world/core/services/support_service.dart';

class SupportState {
  const SupportState({
    this.tickets = const [],
    this.ticketDetails = const {},
    this.isLoadingHistory = false,
    this.isSubmitting = false,
    this.activeTicketId,
    this.errorMessage,
  });

  final List<SupportTicketRecord> tickets;
  final Map<int, SupportTicketRecord> ticketDetails;
  final bool isLoadingHistory;
  final bool isSubmitting;
  final int? activeTicketId;
  final String? errorMessage;

  SupportTicketRecord? ticketDetailFor(int ticketId) {
    return ticketDetails[ticketId] ??
        tickets.cast<SupportTicketRecord?>().firstWhere(
              (item) => item?.id == ticketId,
              orElse: () => null,
            );
  }

  SupportState copyWith({
    List<SupportTicketRecord>? tickets,
    Map<int, SupportTicketRecord>? ticketDetails,
    bool? isLoadingHistory,
    bool? isSubmitting,
    int? activeTicketId,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SupportState(
      tickets: tickets ?? this.tickets,
      ticketDetails: ticketDetails ?? this.ticketDetails,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      activeTicketId: activeTicketId ?? this.activeTicketId,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final supportControllerProvider =
    StateNotifierProvider.autoDispose<SupportController, SupportState>(
  (ref) {
    final service = ref.watch(supportServiceProvider);
    return SupportController(service: service);
  },
);

class SupportController extends StateNotifier<SupportState> {
  SupportController({required SupportService service})
      : _service = service,
        super(const SupportState());

  final SupportService _service;

  Future<void> loadTickets() async {
    state = state.copyWith(isLoadingHistory: true, clearError: true);
    try {
      final tickets = await _service.fetchTickets();
      state = state.copyWith(
        tickets: tickets,
        isLoadingHistory: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingHistory: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<bool> sendMessage({
    required String subject,
    required String message,
    required String category,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
    );
    try {
      final ticket = await _service.sendContactMessage(
        subject: subject,
        message: message,
        category: category,
      );
      state = state.copyWith(
        isSubmitting: false,
        tickets: [ticket, ...state.tickets],
        ticketDetails: {
          ...state.ticketDetails,
          ticket.id: ticket,
        },
        activeTicketId: ticket.id,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<void> loadTicketDetail(int ticketId) async {
    state = state.copyWith(activeTicketId: ticketId, clearError: true);
    try {
      final ticket = await _service.fetchTicketDetail(ticketId);
      state = state.copyWith(
        ticketDetails: {
          ...state.ticketDetails,
          ticketId: ticket,
        },
        tickets: state.tickets
            .map((item) => item.id == ticketId ? ticket : item)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<bool> replyToTicket({
    required int ticketId,
    required String message,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      activeTicketId: ticketId,
      clearError: true,
    );
    try {
      final ticket = await _service.replyToTicket(
        ticketId: ticketId,
        message: message,
      );
      state = state.copyWith(
        isSubmitting: false,
        ticketDetails: {
          ...state.ticketDetails,
          ticketId: ticket,
        },
        tickets: state.tickets
            .map((item) => item.id == ticketId ? ticket : item)
            .toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final supportServiceProvider = Provider<SupportService>((ref) {
  final networkService = ref.watch(networkServiceProvider);
  final logger = ref.watch(loggerProvider);
  return SupportService(
    networkService: networkService,
    logger: logger,
  );
});
