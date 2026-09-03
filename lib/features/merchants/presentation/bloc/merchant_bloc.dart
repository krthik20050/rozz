import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:rozz/features/merchants/data/datasources/merchant_local_datasource.dart';
import 'package:rozz/features/merchants/domain/entities/merchant.dart';
import 'package:rozz/features/merchants/domain/repositories/merchant_repository.dart';
import 'package:rozz/shared/utils/merchant_key.dart';

part 'merchant_event.dart';
part 'merchant_state.dart';

class MerchantBloc extends Bloc<MerchantEvent, MerchantState> {
  final MerchantRepository _repository;

  MerchantBloc(this._repository) : super(MerchantInitial()) {
    on<LoadMerchants>(_onLoadMerchants);
    on<SaveMerchantDescription>(_onSaveDescription);
    on<ClearMerchantDescription>(_onClearDescription);
  }

  Future<void> _onLoadMerchants(
    LoadMerchants event,
    Emitter<MerchantState> emit,
  ) async {
    emit(MerchantLoading());
    try {
      final merchants = await _repository.getMerchants();
      emit(MerchantLoaded(merchants: merchants));
    } catch (e) {
      emit(MerchantError(e.toString()));
    }
  }

  Future<void> _onSaveDescription(
    SaveMerchantDescription event,
    Emitter<MerchantState> emit,
  ) async {
    try {
      // Ensure the merchant row exists, seeding aliases so future SMS and
      // statement rows resolve to this same central ID.
      await _repository.createMerchant(
        event.merchantKey,
        event.canonicalName,
        'user',
      );
      await _seedAliases(event);
      final apply = await _repository.applyDescription(
        merchantKey: event.merchantKey,
        description: event.description,
        merchantWide: event.merchantWide,
        triggerTxId: event.triggerTxId,
      );
      emit(MerchantLoaded(
        merchants: await _repository.getMerchants(),
        lastApply: apply,
      ));
    } catch (e) {
      emit(MerchantError(e.toString()));
    }
  }

  Future<void> _seedAliases(SaveMerchantDescription event) async {
    final seeds = MerchantKey.aliasKeysFor(
      recipientName: event.recipientName,
      upiId: event.upiId,
      labelType: event.labelType,
      direction: 'debit',
    );
    for (final seed in seeds) {
      if (seed == event.merchantKey) continue;
      await _repository.addAlias(seed, event.merchantKey);
    }
  }

  Future<void> _onClearDescription(
    ClearMerchantDescription event,
    Emitter<MerchantState> emit,
  ) async {
    try {
      final merchant = await _repository.getMerchant(event.merchantKey);
      final apply = await _repository.clearDescription(
        merchantKey: event.merchantKey,
        currentDescription: merchant?.description,
      );
      emit(MerchantLoaded(
        merchants: await _repository.getMerchants(),
        lastApply: apply,
      ));
    } catch (e) {
      emit(MerchantError(e.toString()));
    }
  }
}
