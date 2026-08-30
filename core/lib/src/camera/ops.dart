/// PTP operation and response codes for the Nikon Z USB interface.
///
/// Standard codes are from the PTP spec; the 0x90xx/0x94xx vendor codes are
/// from the Z50II MTP spec, section 6.2 (vendor operations), of which the
/// Picture Control set (6.2.9) is what lets a host register picture
/// controls directly in the camera.
abstract final class PtpOps {
  // Standard PTP.
  static const int getDeviceInfo = 0x1001;
  static const int openSession = 0x1002;
  static const int closeSession = 0x1003;

  // Nikon vendor: Picture Control (spec 6.2.9).
  static const int getPicCtrlData = 0x90CC;
  static const int setPicCtrlData = 0x90CD;
  static const int getPicCtrlDataList = 0x9443;
}

/// Nikon Picture Control slots (spec 6.5.14.1, ActivePicCtrlItem).
///
/// 1..20 are the pre-installed/creative types; 201..209 are the user
/// "Custom Picture Control" slots 1..9. Registering into a custom slot with
/// ModifiedFlag=0 creates a new custom picture control that the user can
/// then pick in the camera's picture control menu.
abstract final class PicCtrlItem {
  static const int customFirst = 201;
  static const int customLast = 209;
  static const int customCount = customLast - customFirst + 1;

  static int customSlot(int slot) {
    if (slot < 1 || slot > customCount) {
      throw ArgumentError.value(slot, 'slot', 'must be 1..$customCount');
    }
    return customFirst + slot - 1;
  }

  static int? slotOf(int picCtrlItem) =>
      picCtrlItem >= customFirst && picCtrlItem <= customLast
          ? picCtrlItem - customFirst + 1
          : null;
}

/// PTP response codes (the values Nikon's spec references).
abstract final class PtpRc {
  static const int ok = 0x5000;
  static const int generalError = 0x5001;
  static const int selectionNotFound = 0x5002;
  static const int storageFull = 0x5003;
  static const int invalidStorage = 0x5004;
  static const int invalidTransferParam = 0x5005;
  static const int deviceBusy = 0x5006;
  static const int illegalConfiguration = 0x5007;
  static const int invalidObjectFormat = 0x5008;
  static const int accessDenied = 0x5009;
  static const int unreachable = 0x500A;
  static const int invalidParameter = 0x500B;
  static const int objectWritesProtected = 0x500C;
  static const int storeFull = 0x500D;
  static const int partialTransfer = 0x500E;
  static const int hardwareFault = 0x5010;
  static const int invalidObjectHandle = 0x5011;
  static const int invalidDeviceHandle = 0x5012;
  static const int sessionNotOpen = 0x5013;
  static const int operationNotSupported = 0x5014;
  static const int invalidTransactionId = 0x5015;
  static const int noMemory = 0x501E;
  static const int invalidPropValue = 0x501F;

  static String name(int code) => switch (code) {
        ok => 'OK',
        generalError => 'General_Error',
        selectionNotFound => 'Selection_Not_Found',
        storageFull => 'Storage_Full',
        invalidStorage => 'Invalid_Storage',
        invalidTransferParam => 'Invalid_Transfer_Parameter',
        deviceBusy => 'Device_Busy',
        illegalConfiguration => 'Illegal_Configuration',
        invalidObjectFormat => 'Invalid_Object_Format',
        accessDenied => 'Access_Denied',
        unreachable => 'Unreachable',
        invalidParameter => 'Invalid_Parameter',
        objectWritesProtected => 'Object_Writes_Protected',
        storeFull => 'Store_Full',
        partialTransfer => 'Partial_Transfer',
        hardwareFault => 'Hardware_Fault',
        invalidObjectHandle => 'Invalid_Object_Handle',
        invalidDeviceHandle => 'Invalid_Device_Handle',
        sessionNotOpen => 'Session_Not_Open',
        operationNotSupported => 'Operation_Not_Supported',
        invalidTransactionId => 'Invalid_TransactionID',
        noMemory => 'No_Memory',
        invalidPropValue => 'Invalid_Prop_Value',
        _ => 'Unknown(0x${code.toRadixString(16).padLeft(4, '0')})',
      };
}