import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../shared/widgets/confirmation_dialog.dart';

import '../../shared/services/service_repository.dart';
import '../../shared/models/service_model.dart';
import '../../shared/models/user_model.dart';
import '../../shared/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/form_widgets.dart';
import '../../core/services/storage_service.dart';
import '../../shared/models/booking_forms_model.dart';
import '../../shared/services/lookup_service.dart';
import '../../shared/widgets/app_network_image.dart';

class ProviderServiceFormScreen extends ConsumerStatefulWidget {
  final String? serviceId;

  const ProviderServiceFormScreen({this.serviceId, super.key});

  @override
  ConsumerState<ProviderServiceFormScreen> createState() =>
      _ProviderServiceFormScreenState();
}

class _ProviderServiceFormScreenState
    extends ConsumerState<ProviderServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  String? _selectedCategory;
  ServiceStatus _status = ServiceStatus.active;
  List<dynamic> _images = []; // Can be String (URL) or XFile (local)
  bool _isUploading = false;

  late TextEditingController _regionController;

  // Common Fields
  late TextEditingController _titleController;
  late TextEditingController _priceController;
  late TextEditingController _locationController;
  late TextEditingController _descriptionController;
  String _pricingType = 'nightly';

  // Hotel Specific
  late TextEditingController _hotelNameController;
  late TextEditingController _hotelRoomsController;
  late TextEditingController _hotelMaxGuestsController;
  final List<String> _hotelAmenities = [];
  String? _bedType = 'Double';
  String? _smokingPreference = 'Non-Smoking';
  bool _breakfastIncluded = false;
  bool _airportPickup = false;
  bool _extraBedAvailable = false;
  late TextEditingController _breakfastPriceController;
  late TextEditingController _airportPickupPriceController;
  late TextEditingController _extraBedPriceController;
  final List<Map<String, dynamic>> _customRoomOptions = [];

  // Bed Type Prices
  bool _singleBedEnabled = false;
  bool _doubleBedEnabled = false;
  bool _twinBedEnabled = false;
  late TextEditingController _singleBedPriceController;
  late TextEditingController _doubleBedPriceController;
  late TextEditingController _twinBedPriceController;
  late TextEditingController _singleRoomsController;
  late TextEditingController _doubleRoomsController;
  late TextEditingController _twinRoomsController;

  // Apartment Specific
  String? _apartmentType;
  late TextEditingController _floorNumberController;
  late TextEditingController _aptRoomsController;
  late TextEditingController _aptBedroomsController;
  late TextEditingController _aptBathroomsController;
  late TextEditingController _aptMaxGuestsController;
  bool _aptFurnished = false;
  bool _hasElevator = false;
  bool _hasParking = false;
  bool _cleaningAvailable = false;
  late TextEditingController _houseRulesController;
  late TextEditingController _cleaningPriceController;
  final List<String> _aptAmenities = [];

  // Tour Specific
  late TextEditingController _durationController;
  late TextEditingController _meetingPointController;
  late TextEditingController _maxTravelersController;
  late TextEditingController _tourInclusionsController;
  late TextEditingController _tourExclusionsController;
  late TextEditingController _tourItineraryController;
  late TextEditingController _tourImportantInfoController;
  String _tourDifficulty = 'Moderate';
  final List<String> _tourLanguages = ['English'];
  final List<String> _tourIncludes = [];
  final List<String> _tourExcludes = [];
  TourPackage _selectedTourPackage = TourPackage.jumma;

  // Jumma Specific
  late TextEditingController _preferredLocationController;
  late TextEditingController _jummaTransportController;
  String _accommodationType = 'Hotel';
  bool _includeLunch = true;

  // Eid Specific
  String _eidType = 'Eid al-Fitr';
  late TextEditingController _eidTransportController;
  late TextEditingController _eidFoodController;
  int _hotelRating = 4;

  // Custom Specific
  late TextEditingController _budgetRangeController;
  final List<String> _availableServices = [];

  // Eid / Tour Additional
  late TextEditingController _eidDestinationController;
  late TextEditingController _eidDaysController;
  late TextEditingController _adultPriceController;
  late TextEditingController _childPriceController;

  // Extra Services
  late TextEditingController _guidePriceController;
  late TextEditingController _privateTransportPriceController;
  late TextEditingController _photographerPriceController;
  late TextEditingController _vipAccessPriceController;
  late TextEditingController _translatorPriceController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _priceController = TextEditingController();
    _locationController = TextEditingController();
    _descriptionController = TextEditingController();

    // Hotel
    _hotelNameController = TextEditingController();
    _hotelRoomsController = TextEditingController();
    _hotelMaxGuestsController = TextEditingController();
    _breakfastPriceController = TextEditingController();
    _airportPickupPriceController = TextEditingController();
    _extraBedPriceController = TextEditingController();
    _singleBedPriceController = TextEditingController();
    _doubleBedPriceController = TextEditingController();
    _twinBedPriceController = TextEditingController();
    _singleRoomsController = TextEditingController();
    _doubleRoomsController = TextEditingController();
    _twinRoomsController = TextEditingController();
    _regionController = TextEditingController();

    // Apartment
    _floorNumberController = TextEditingController();
    _aptRoomsController = TextEditingController();
    _aptBedroomsController = TextEditingController();
    _aptBathroomsController = TextEditingController();
    _aptMaxGuestsController = TextEditingController();
    _houseRulesController = TextEditingController();
    _cleaningPriceController = TextEditingController();

    // Tour
    _durationController = TextEditingController();
    _meetingPointController = TextEditingController();
    _maxTravelersController = TextEditingController();
    _tourInclusionsController = TextEditingController();
    _tourExclusionsController = TextEditingController();
    _tourItineraryController = TextEditingController();
    _tourImportantInfoController = TextEditingController();
    _adultPriceController = TextEditingController();
    _childPriceController = TextEditingController();

    _guidePriceController = TextEditingController();
    _privateTransportPriceController = TextEditingController();
    _photographerPriceController = TextEditingController();
    _vipAccessPriceController = TextEditingController();
    _translatorPriceController = TextEditingController();

    // Jumma
    _preferredLocationController = TextEditingController(text: 'Mogadishu');
    _jummaTransportController = TextEditingController(text: 'Car');

    // Eid
    _eidTransportController = TextEditingController(text: 'Bus');
    _eidFoodController = TextEditingController(text: 'Full board');

    // Custom
    _budgetRangeController = TextEditingController(text: '\$500 - \$1000');

    // Eid / Tour Additional
    _eidDestinationController = TextEditingController();
    _eidDaysController = TextEditingController(text: '3');

    if (widget.serviceId != null) {
      _loadServiceData();
    } else {
      // Auto-populate location from provider profile for new services
      final user = ref.read(authProvider);
      if (user?.location != null && user!.location!.isNotEmpty) {
        _locationController.text = user.location!;
        // Only use as region if it doesn't look like a full address (contains comma)
        if (!user.location!.contains(',')) {
          _regionController.text = user.location!;
        }
      }
      if (user?.metadata['default_base_price'] != null) {
        _priceController.text = user!.metadata['default_base_price'].toString();
      }
    }
  }

  void _loadServiceData() {
    Future.microtask(() {
      final services = ref.read(filteredServicesProvider);

      try {
        final service = services.firstWhere((s) => s.id == widget.serviceId);
        setState(() {
          _titleController.text = service.title;
          _selectedCategory = service.category;
          _priceController.text = service.price.toString();
          _pricingType =
              service.metadata['pricing_type'] ??
              (service.category.toLowerCase().contains('apartment')
                  ? 'monthly'
                  : 'nightly');
          _locationController.text = service.location;
          _descriptionController.text = service.description;
          _status = service.status;
          _images = List.from(service.images);

          // Populate metadata if available
          if (service.metadata.isNotEmpty) {
            if (service.metadata['region'] != null) {
              final regionValue = service.metadata['region'].toString();
              // Sanitize: do not use if it looks like a full address
              // Sanitize: do not use if it looks like a full address
              if (!regionValue.contains(',')) {
                _regionController.text = regionValue;
              }
            }
            _populateMetadata(service.category, service.metadata);
          }

          final categoryLower = service.category.trim().toLowerCase();
          // Populate extra prices from explicit fields
          if (categoryLower.contains('hotel')) {
            _breakfastPriceController.text =
                service.breakfastPrice?.toString() ?? '';
            _airportPickupPriceController.text =
                service.airportPickupPrice?.toString() ?? '';
            _extraBedPriceController.text =
                service.extraBedPrice?.toString() ?? '';

            // Ensure amenities are loaded even if not in metadata
            if (service.amenities != null) {
              _hotelAmenities.clear();
              _hotelAmenities.addAll(List<String>.from(service.amenities!));
            }
          } else if (categoryLower.contains('apartment')) {
            _cleaningPriceController.text =
                service.cleaningPrice?.toString() ?? '';

            // Ensure amenities are loaded even if not in metadata
            if (service.amenities != null) {
              _aptAmenities.clear();
              _aptAmenities.addAll(List<String>.from(service.amenities!));
            }
          }
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error loading service data')),
          );
        }
      }
    });
  }

  void _populateMetadata(String category, Map<String, dynamic> metadata) {
    final catLower = category.trim().toLowerCase();
    switch (catLower) {
      case 'hotel':
      case 'hotels':
        _hotelNameController.text = metadata['hotelName'] ?? '';
        _hotelRoomsController.text = metadata['rooms']?.toString() ?? '';
        _hotelMaxGuestsController.text =
            (metadata['max_guests'] ?? metadata['maxGuests'])?.toString() ?? '';
        if (metadata['amenities'] != null) {
          _hotelAmenities.clear();
          _hotelAmenities.addAll(List<String>.from(metadata['amenities']));
        }
        _bedType = metadata['bedType'];
        _smokingPreference = metadata['smokingPreference'];
        _breakfastIncluded = metadata['breakfastIncluded'] ?? false;
        _airportPickup = metadata['airportPickup'] ?? false;
        _extraBedAvailable = metadata['extraBedAvailable'] ?? false;

        if (metadata['custom_room_options'] != null) {
          _customRoomOptions.clear();
          _customRoomOptions.addAll(
            List<Map<String, dynamic>>.from(metadata['custom_room_options']),
          );
        }

        final bedTypes = metadata['bed_types_dynamic'] as Map<String, dynamic>?;
        if (bedTypes != null) {
          _singleBedEnabled = bedTypes['single']?['enabled'] ?? false;
          _singleBedPriceController.text =
              bedTypes['single']?['price']?.toString() ?? '';
          _singleRoomsController.text =
              bedTypes['single']?['count']?.toString() ?? '';

          _doubleBedEnabled = bedTypes['double']?['enabled'] ?? false;
          _doubleBedPriceController.text =
              bedTypes['double']?['price']?.toString() ?? '';
          _doubleRoomsController.text =
              bedTypes['double']?['count']?.toString() ?? '';

          _twinBedEnabled = bedTypes['twin']?['enabled'] ?? false;
          _twinBedPriceController.text =
              bedTypes['twin']?['price']?.toString() ?? '';
          _twinRoomsController.text =
              bedTypes['twin']?['count']?.toString() ?? '';
        } else if (_bedType != null) {
          // Fallback for old data
          if (_bedType == 'Single') _singleBedEnabled = true;
          if (_bedType == 'Double') _doubleBedEnabled = true;
          if (_bedType == 'Twin') _twinBedEnabled = true;
        }
        break;

      case 'apartment':
      case 'apartments':
        _apartmentType = metadata['apartmentType'];
        _floorNumberController.text = metadata['floorNumber']?.toString() ?? '';
        _aptRoomsController.text = metadata['rooms']?.toString() ?? '';
        _aptBedroomsController.text = metadata['bedrooms']?.toString() ?? '';
        _aptBathroomsController.text = metadata['bathrooms']?.toString() ?? '';
        _aptMaxGuestsController.text =
            (metadata['max_guests'] ?? metadata['maxGuests'])?.toString() ?? '';
        _aptFurnished = metadata['furnished'] ?? false;
        _hasElevator = metadata['elevator'] ?? false;
        _hasParking = metadata['parking'] ?? false;
        _cleaningAvailable = metadata['cleaningAvailable'] ?? false;
        _houseRulesController.text = metadata['houseRules'] ?? '';
        if (metadata['amenities'] != null) {
          _aptAmenities.clear();
          _aptAmenities.addAll(List<String>.from(metadata['amenities']));
        }
        break;
      case 'tour':
      case 'tours':
        _durationController.text = metadata['duration'] ?? '';
        _meetingPointController.text = metadata['meetingPoint'] ?? '';
        _maxTravelersController.text =
            (metadata['max_guests'] ?? metadata['maxTravelers'])?.toString() ??
            '';
        _tourLanguages.clear();
        if (metadata['languages'] != null) {
          _tourLanguages.addAll(List<String>.from(metadata['languages']));
        }
        _tourInclusionsController.text = metadata['tourInclusions'] ?? '';
        _tourExclusionsController.text = metadata['tourExclusions'] ?? '';
        _tourItineraryController.text = metadata['tourItinerary'] ?? '';
        _tourImportantInfoController.text = metadata['tourImportantInfo'] ?? '';
        _tourDifficulty = metadata['tourDifficulty'] ?? 'Moderate';
        if (metadata['includes'] != null) {
          _tourIncludes.clear();
          _tourIncludes.addAll(List<String>.from(metadata['includes']));
        }

        // Restore Package
        final packageStr = metadata['package'] ?? 'jumma';
        _selectedTourPackage = TourPackage.values.firstWhere(
          (e) => e.name == packageStr,
          orElse: () => TourPackage.jumma,
        );

        // Restore Package Specific Fields
        if (_selectedTourPackage == TourPackage.jumma) {
          _preferredLocationController.text =
              metadata['preferredLocation'] ?? '';
          _jummaTransportController.text = metadata['jummaTransport'] ?? '';
          _accommodationType = metadata['accommodationType'] ?? 'Hotel';
          _includeLunch = metadata['includeLunch'] ?? true;
        } else if (_selectedTourPackage == TourPackage.eid) {
          _eidType = metadata['eidType'] ?? 'Eid al-Fitr';
          _eidTransportController.text = metadata['eidTransport'] ?? '';
          _hotelRating = metadata['hotelRating'] ?? 4;
          _eidFoodController.text = metadata['foodPackage'] ?? 'Full board';
          _eidDestinationController.text = metadata['destination'] ?? '';
          _eidDaysController.text = metadata['numberOfDays']?.toString() ?? '3';
        } else if (_selectedTourPackage == TourPackage.custom) {
          _budgetRangeController.text = metadata['budgetRange'] ?? '';
          if (metadata['availableServices'] != null) {
            _availableServices.clear();
            _availableServices.addAll(
              List<String>.from(metadata['availableServices']),
            );
          }
        }
        _adultPriceController.text =
            (metadata['adult_price'] ?? metadata['adultPrice'])?.toString() ??
            '';
        _childPriceController.text =
            (metadata['child_price'] ?? metadata['childPrice'])?.toString() ??
            '';

        final extraPrices =
            metadata['extraServicePrices'] as Map<String, dynamic>? ?? {};
        _guidePriceController.text = extraPrices['Guide']?.toString() ?? '';
        _privateTransportPriceController.text =
            extraPrices['Private Transport']?.toString() ?? '';
        _photographerPriceController.text =
            extraPrices['Photographer']?.toString() ?? '';
        _vipAccessPriceController.text =
            extraPrices['VIP Access']?.toString() ?? '';
        _translatorPriceController.text =
            extraPrices['Translator']?.toString() ?? '';
        break;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();

    _durationController.dispose();
    _meetingPointController.dispose();
    _maxTravelersController.dispose();
    _tourInclusionsController.dispose();
    _tourExclusionsController.dispose();
    _tourItineraryController.dispose();
    _tourImportantInfoController.dispose();
    _hotelNameController.dispose();
    _hotelRoomsController.dispose();
    _hotelMaxGuestsController.dispose();
    _houseRulesController.dispose();
    _breakfastPriceController.dispose();
    _airportPickupPriceController.dispose();
    _extraBedPriceController.dispose();
    _singleBedPriceController.dispose();
    _doubleBedPriceController.dispose();
    _twinBedPriceController.dispose();
    _singleRoomsController.dispose();
    _doubleRoomsController.dispose();
    _twinRoomsController.dispose();
    _cleaningPriceController.dispose();
    _preferredLocationController.dispose();
    _jummaTransportController.dispose();
    _eidTransportController.dispose();
    _eidFoodController.dispose();
    _budgetRangeController.dispose();
    _eidDestinationController.dispose();
    _eidDaysController.dispose();
    _adultPriceController.dispose();
    _childPriceController.dispose();
    _guidePriceController.dispose();
    _privateTransportPriceController.dispose();
    _photographerPriceController.dispose();
    _vipAccessPriceController.dispose();
    _translatorPriceController.dispose();
    _regionController.dispose();

    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (_titleController.text.isNotEmpty) {
      final shouldPop = await ConfirmationDialog.show(
        context: context,
        title: 'Unsaved Changes',
        message: 'Do you want to discard your changes?',
        confirmLabel: 'Yes, Discard',
        type: ConfirmationDialogType.danger,
        icon: Icons.warning_amber_rounded,
      );
      return shouldPop ?? false;
    }
    return true;
  }

  Future<void> _pickImage() async {
    if (_images.length >= 20) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Max 20 images allowed')));
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _images.add({'file': image, 'bytes': bytes});
          });
        } else {
          setState(() {
            _images.add(image);
          });
        }
      }
    } catch (e) {
      if (context.mounted) {
        String message = 'Error picking image: $e';
        if (e.toString().contains('channel-error')) {
          message =
              'Native plugin not linked. Please STOP the app and RUN it again (full restart required).';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 5),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _saveService() async {
    if (_formKey.currentState!.validate()) {
      if (_images.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add at least one image')),
        );
        return;
      }

      final isEditing = widget.serviceId != null;
      final actionVerb = isEditing ? 'Update' : 'Create';

      final confirmed = await ConfirmationDialog.show(
        context: context,
        title: '$actionVerb Service?',
        message:
            'Confirm Action: Do you want to $actionVerb this ${_selectedCategory?.toLowerCase() ?? 'service'}?',
        confirmLabel: 'Yes, $actionVerb',
        type: ConfirmationDialogType.info,
        icon: isEditing ? Icons.edit_note : Icons.add_business_outlined,
      );

      if (confirmed != true) return;

      setState(() => _isUploading = true);

      try {
        // 1. Upload new images
        final List<String> finalImageUrls = [];
        try {
          for (final item in _images) {
            if (item is String) {
              finalImageUrls.add(item); // Already a URL
            } else if (item is XFile) {
              final url = await StorageService.uploadImage(item);
              if (url != null) {
                finalImageUrls.add(url);
              }
            } else if (item is Map && item.containsKey('file')) {
              final url = await StorageService.uploadImage(
                item['file'] as XFile,
                bytes: item['bytes'] as List<int>?,
              );
              if (url != null) {
                finalImageUrls.add(url);
              }
            }
          }
        } catch (uploadError) {
          debugPrint('DEBUG: Detailed Upload Error: $uploadError');
          throw Exception(
            'Image upload failed: $uploadError. Please make sure storage bucket is configured.',
          );
        }

        if (finalImageUrls.isEmpty && _images.isNotEmpty) {
          throw Exception(
            'Failed to upload images: List is empty after processing. Check console logs.',
          );
        }

        final title = _titleController.text;
        final category = _selectedCategory!;
        final price = double.parse(_priceController.text);
        final location = _locationController.text;
        final description = _descriptionController.text;

        // Collect Metadata
        final Map<String, dynamic> metadata = {};
        if (_regionController.text.isNotEmpty) {
          metadata['region'] = _regionController.text;
        }
        metadata['pricing_type'] = _pricingType;
        switch (category.toLowerCase()) {
          case 'hotel':
          case 'hotels':
            metadata['hotelName'] = _hotelNameController.text;
            metadata['rooms'] = int.tryParse(_hotelRoomsController.text);
            metadata['max_guests'] = int.tryParse(_hotelMaxGuestsController.text);
            metadata['amenities'] = _hotelAmenities;
            metadata['bedType'] = _bedType;
            metadata['smokingPreference'] = _smokingPreference;
            metadata['breakfastIncluded'] = _breakfastIncluded;
            metadata['airportPickup'] = _airportPickup;
            metadata['extraBedAvailable'] = _extraBedAvailable;
            metadata['custom_room_options'] = _customRoomOptions;
            metadata['bed_types_dynamic'] = {
              'single': {
                'enabled': _singleBedEnabled,
                'price': 0.0, // Single is now automatic/base
                'count': int.tryParse(_singleRoomsController.text) ?? 0,
              },
              'double': {
                'enabled': _doubleBedEnabled,
                'price': double.tryParse(_doubleBedPriceController.text) ?? 0.0,
                'count': int.tryParse(_doubleRoomsController.text) ?? 0,
              },
              'twin': {
                'enabled': _twinBedEnabled,
                'price': double.tryParse(_twinBedPriceController.text) ?? 0.0,
                'count': int.tryParse(_twinRoomsController.text) ?? 0,
              },
            };
            break;

          case 'apartment':
          case 'apartments':
            metadata['apartmentType'] = _apartmentType;
            metadata['floorNumber'] = int.tryParse(_floorNumberController.text);
            metadata['rooms'] = int.tryParse(_aptRoomsController.text);
            metadata['bedrooms'] = int.tryParse(_aptBedroomsController.text);
            metadata['bathrooms'] = int.tryParse(_aptBathroomsController.text);
            metadata['max_guests'] = int.tryParse(_aptMaxGuestsController.text);
            metadata['furnished'] = _aptFurnished;
            metadata['elevator'] = _hasElevator;
            metadata['parking'] = _hasParking;
            metadata['cleaningAvailable'] = _cleaningAvailable;
            metadata['houseRules'] = _houseRulesController.text;
            metadata['amenities'] = _aptAmenities;
            break;
          case 'tour':
          case 'tours':
            metadata['duration'] = _durationController.text;
            metadata['meetingPoint'] = _meetingPointController.text;
            metadata['max_guests'] = int.tryParse(_maxTravelersController.text);
            metadata['languages'] = _tourLanguages;
            metadata['includes'] = _tourIncludes;
            metadata['package'] = _selectedTourPackage.name;
            metadata['tourInclusions'] = _tourInclusionsController.text;
            metadata['tourExclusions'] = _tourExclusionsController.text;
            metadata['tourItinerary'] = _tourItineraryController.text;
            metadata['tourImportantInfo'] = _tourImportantInfoController.text;
            metadata['tourDifficulty'] = _tourDifficulty;

            // Save Package Specific Fields
            if (_selectedTourPackage == TourPackage.jumma) {
              metadata['preferredLocation'] = _preferredLocationController.text;
              metadata['jummaTransport'] = _jummaTransportController.text;
              metadata['accommodationType'] = _accommodationType;
              metadata['includeLunch'] = _includeLunch;
            } else if (_selectedTourPackage == TourPackage.eid) {
              metadata['eidType'] = _eidType;
              metadata['eidTransport'] = _eidTransportController.text;
              metadata['hotelRating'] = _hotelRating;
              metadata['foodPackage'] = _eidFoodController.text;
              metadata['destination'] = _eidDestinationController.text;
              metadata['numberOfDays'] = int.tryParse(_eidDaysController.text);
            } else if (_selectedTourPackage == TourPackage.custom) {
              metadata['budgetRange'] = _budgetRangeController.text;
              metadata['availableServices'] = _availableServices;
            }

            // Core Pricing for Tours
            metadata['adult_price'] = double.tryParse(
              _adultPriceController.text,
            );
            metadata['child_price'] = double.tryParse(
              _childPriceController.text,
            );

            // Extra Services Pricing
            metadata['extraServicePrices'] = {
              'Guide': double.tryParse(_guidePriceController.text) ?? 0.0,
              'Private Transport':
                  double.tryParse(_privateTransportPriceController.text) ?? 0.0,
              'Photographer':
                  double.tryParse(_photographerPriceController.text) ?? 0.0,
              'VIP Access':
                  double.tryParse(_vipAccessPriceController.text) ?? 0.0,
              'Translator':
                  double.tryParse(_translatorPriceController.text) ?? 0.0,
            };
            break;
        }

        if (widget.serviceId != null) {
          // Update existing
          final existingService = ref
              .read(filteredServicesProvider)
              .firstWhere((s) => s.id == widget.serviceId!);

          final updatedService = existingService.copyWith(
            title: title,
            category: category,
            price: price,
            location: location,
            description: description,
            status: _status,
            images: finalImageUrls,
            metadata: metadata,
            amenities: category.trim().toLowerCase().contains('hotel')
                ? List<String>.from(_hotelAmenities)
                : (category.trim().toLowerCase().contains('apartment')
                      ? List<String>.from(_aptAmenities)
                      : null),
            breakfastPrice: double.tryParse(_breakfastPriceController.text),
            airportPickupPrice: double.tryParse(
              _airportPickupPriceController.text,
            ),
            extraBedPrice: double.tryParse(_extraBedPriceController.text),
            maxGuests: category.trim().toLowerCase().contains('hotel')
                ? (int.tryParse(_hotelMaxGuestsController.text) ?? 2)
                : (category.trim().toLowerCase().contains('apartment')
                      ? int.tryParse(_aptMaxGuestsController.text)
                      : int.tryParse(_maxTravelersController.text)),
            cleaningPrice: double.tryParse(_cleaningPriceController.text),
            adultPrice: double.tryParse(_adultPriceController.text),
            childPrice: double.tryParse(_childPriceController.text),
            availableSlots: category.toLowerCase().contains('hotel')
                ? (int.tryParse(_hotelRoomsController.text) ?? 1) -
                      (existingService.metadata['bookedRooms'] as num? ?? 0)
                          .toInt()
                : (category.toLowerCase().contains('apartment')
                      ? 1
                      : (int.tryParse(_maxTravelersController.text) ?? 10)),
          );

          await ref
              .read(serviceProvider.notifier)
              .updateService(updatedService);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Service updated successfully!'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } else {
          // Create new
          final user = ref.read(authProvider);
          if (user == null) {
            throw Exception('User session invalid. Please login again.');
          }

          final providerIdToUse = user.providerId ?? user.id;

          // Duplicate check removed to allow flexibility
          /*
          if (!ref
              .read(serviceProvider.notifier)
              .isServiceUnique(title, providerIdToUse)) {
            throw Exception('A service with this title already exists.');
          }
          */

          final newService = Service(
            id: '',
            providerId: providerIdToUse,
            title: title,
            category: category,
            price: price,
            location: location,
            description: description,
            status: _status,
            images: finalImageUrls,
            metadata: metadata,
            amenities: category.trim().toLowerCase().contains('hotel')
                ? List<String>.from(_hotelAmenities)
                : (category.trim().toLowerCase().contains('apartment')
                      ? List<String>.from(_aptAmenities)
                      : null),
            breakfastPrice: double.tryParse(_breakfastPriceController.text),
            airportPickupPrice: double.tryParse(
              _airportPickupPriceController.text,
            ),
            extraBedPrice: double.tryParse(_extraBedPriceController.text),
            maxGuests: category.trim().toLowerCase().contains('hotel')
                ? (int.tryParse(_hotelMaxGuestsController.text) ?? 2)
                : (category.trim().toLowerCase().contains('apartment')
                      ? int.tryParse(_aptMaxGuestsController.text)
                      : int.tryParse(_maxTravelersController.text)),
            cleaningPrice: double.tryParse(_cleaningPriceController.text),
            adultPrice: double.tryParse(_adultPriceController.text),
            childPrice: double.tryParse(_childPriceController.text),
            availableSlots: category.toLowerCase().contains('hotel')
                ? (int.tryParse(_hotelRoomsController.text) ?? 1)
                : (category.toLowerCase().contains('apartment')
                      ? 1
                      : (int.tryParse(_maxTravelersController.text) ?? 10)),
          );

          await ref.read(serviceProvider.notifier).addService(newService);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Service created successfully!'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
        if (mounted) {
          context.go('/provider/dashboard');
        }
      } catch (e) {
        if (mounted) {
          String errorMsg = e.toString();
          if (errorMsg.contains('PostgrestException')) {
            // Try to extract a cleaner message
            final regex = RegExp(r"message:\s*(.+?),");
            final match = regex.firstMatch(errorMsg);
            if (match != null) {
              errorMsg = match.group(1) ?? errorMsg;
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving service: $errorMsg'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final isEditing = widget.serviceId != null;
    final user = ref.watch(authProvider);
    final providerType = user?.providerType ?? ProviderType.hotel;

    // Filter categories based on provider type
    final List<LookupItem> filteredCategories = categoriesAsync.when(
      data: (categories) => categories.where((c) {
        final catId = c.key; // Using key instead of 'id' from LookupItem
        switch (providerType) {
          case ProviderType.hotel:
            return catId.toLowerCase() == 'hotel';
          case ProviderType.home:
          case ProviderType.apartment:
            return catId.toLowerCase() == 'apartment';
          case ProviderType.all:
          case ProviderType.tour:
            return catId.toLowerCase() == 'tour';
        }
      }).toList(),
      loading: () => [],
      error: (_, __) => [],
    );

    // Auto-select category synchronously so form renders on first frame
    if (_selectedCategory == null &&
        !isEditing &&
        filteredCategories.isNotEmpty) {
      _selectedCategory = filteredCategories.first.key;
    }

    String typeLabel = 'Service';
    switch (providerType) {
      case ProviderType.hotel:
        typeLabel = 'Hotel';
        break;
      case ProviderType.home:
        typeLabel = 'Apartment';
        break;
      case ProviderType.apartment:
        typeLabel = 'Apartment';
        break;
      case ProviderType.all:
        typeLabel = 'All Services';
        break;
      case ProviderType.tour:
        typeLabel = 'Tour';
        break;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Edit $typeLabel' : 'Add New $typeLabel'),
          actions: [
            if (isEditing)
              IconButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Service?'),
                      content: const Text(
                        'Are you sure you want to permanently delete this service?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await ref
                        .read(serviceProvider.notifier)
                        .deleteService(widget.serviceId!);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Service deleted successfully'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      context.pop();
                    }
                  }
                },
                icon: const Icon(Icons.delete_outline, color: Colors.white),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (filteredCategories.length > 1) ...[
                  _buildCategorySelection(filteredCategories),
                  const SizedBox(height: 32),
                ],

                categoriesAsync.when(
                  data: (categories) {
                    if (categories.isEmpty || filteredCategories.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 60),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(
                                Icons.category_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No categories available for $typeLabel.',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Please contact support or try again later.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: _selectedCategory == null
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                              key: ValueKey(_selectedCategory),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildCommonFields(),
                                const SizedBox(height: 32),
                                _buildCategorySpecificFields(),
                                const SizedBox(height: 32),
                                _buildDescriptionSection(),
                                const SizedBox(height: 32),
                                _buildImageSection(),
                                const SizedBox(height: 32),
                                _buildStatusSection(),
                                const SizedBox(height: 48),
                                _buildActionButtons(),
                              ],
                            ),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 100),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, stack) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading categories: $err',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelection(List<LookupItem> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Category'),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((c) {
              final id = c.key;
              final name = c.label;
              final icon = getLookupIcon(c.icon);
              final isSelected = _selectedCategory == id;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CategoryCard(
                  name: name,
                  icon: icon,
                  isSelected: isSelected,
                  onTap: () => setState(() => _selectedCategory = id),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCommonFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Basic Information'),
        const SizedBox(height: 16),
        AppTextField(
          controller: _titleController,
          label: 'Service Title *',
          hint: 'enter title for your service',
          validator: (val) =>
              val == null || val.isEmpty ? 'Title is required' : null,
          prefixIcon: const Icon(Icons.title),
        ),
        const SizedBox(height: 16),
        Column(
          children: [
            ref
                .watch(regionsProvider)
                .when(
                  data: (items) {
                    return AppDropdown<String>(
                      label: 'Region (Gobol) *',
                      hint: 'Select Region',
                      value: _regionController.text.isNotEmpty
                          ? _regionController.text
                          : null,
                      items: items.map((e) {
                        return DropdownMenuItem<String>(
                          value: e.label,
                          child: Text(e.label),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _regionController.text = val;
                          });
                        }
                      },
                      validator: (val) => val == null || val.isEmpty
                          ? 'Region is required'
                          : null,
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => AppTextField(
                    controller: _regionController,
                    label: 'Region (Gobol) *',
                    hint: 'Type region name...',
                    prefixIcon: const Icon(Icons.map_outlined),
                  ),
                ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _locationController,
              label: 'District / Degmo *',
              hint: 'e.g. Hodan',
              prefixIcon: const Icon(Icons.location_city_outlined),
              validator: (val) =>
                  val == null || val.isEmpty ? 'District is required' : null,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _priceController,
                label:
                    (_selectedCategory?.toLowerCase().contains('tour') ?? false)
                    ? 'Qiimaha Maalintii (Price per Day) *'
                    : ((_selectedCategory?.toLowerCase().contains(
                                'apartment',
                              ) ??
                              false)
                          ? (_pricingType == 'monthly'
                                ? 'Qiimaha Bishii (Price per Month) *'
                                : 'Qiimaha Habeenkii (Price per Night) *')
                          : 'Qiimaha Habeenkii (Price per Night) *'),
                hint: '0.00',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                prefixIcon: const Icon(Icons.attach_money),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  final num = double.tryParse(val);
                  if (num == null || num <= 0) return 'Invalid price';
                  return null;
                },
              ),
            ),
          ],
        ),
        if (_selectedCategory?.toLowerCase().contains('apartment') ??
            false) ...[
          const SizedBox(height: 16),
          AppDropdown<String>(
            label: 'Nooca Qiimaha (Pricing Type) *',
            value: _pricingType,
            items: [
              const DropdownMenuItem(
                value: 'nightly',
                child: Text('Habeenkii (Nightly)'),
              ),
              const DropdownMenuItem(
                value: 'monthly',
                child: Text('Bishii (Monthly)'),
              ),
            ],
            onChanged: (val) => setState(() => _pricingType = val!),
          ),
        ],
      ],
    );
  }

  Widget _buildCategorySpecificFields() {
    final category = _selectedCategory?.toLowerCase() ?? '';
    switch (category) {
      case 'hotel':
      case 'hotels':
        return _buildHotelFields();
      case 'apartment':
      case 'apartments':
        return _buildApartmentFields();
      case 'tour':
      case 'tours':
        return _buildTourFields();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHotelFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Hotel Details'),
        const SizedBox(height: 16),
        AppTextField(
          controller: _hotelNameController,
          label: 'Hotel Name *',
          hint: 'Enter hotel name',
          prefixIcon: const Icon(Icons.hotel),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _hotelRoomsController,
                label: 'Number of Rooms *',
                hint: 'e.g. 20',
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.meeting_room_outlined),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AppTextField(
                controller: _hotelMaxGuestsController,
                label: 'Max Guests (per room) *',
                hint: 'e.g. 2',
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.people_outline),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  final n = int.tryParse(val);
                  if (n == null || n < 1) return 'Min 1';
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Bed Types & Prices',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Single Bed'),
                    value: _singleBedEnabled,
                    onChanged: (val) => setState(() => _singleBedEnabled = val),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_singleBedEnabled)
                    AppTextField(
                      controller: _singleRoomsController,
                      label: 'Number of Rooms',
                      hint: '5',
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(Icons.meeting_room_outlined),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Double Bed'),
                    value: _doubleBedEnabled,
                    onChanged: (val) => setState(() => _doubleBedEnabled = val),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_doubleBedEnabled)
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _doubleBedPriceController,
                            label: 'Price +',
                            hint: '10.00',
                            keyboardType: TextInputType.number,
                            prefixIcon: const Icon(Icons.attach_money),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppTextField(
                            controller: _doubleRoomsController,
                            label: 'Count',
                            hint: '5',
                            keyboardType: TextInputType.number,
                            prefixIcon: const Icon(Icons.meeting_room_outlined),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Twin Beds'),
                    value: _twinBedEnabled,
                    onChanged: (val) => setState(() => _twinBedEnabled = val),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_twinBedEnabled)
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _twinBedPriceController,
                            label: 'Price +',
                            hint: '5.00',
                            keyboardType: TextInputType.number,
                            prefixIcon: const Icon(Icons.attach_money),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppTextField(
                            controller: _twinRoomsController,
                            label: 'Count',
                            hint: '5',
                            keyboardType: TextInputType.number,
                            prefixIcon: const Icon(Icons.meeting_room_outlined),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AppDropdown<String>(
                label: 'Smoking *',
                value: _smokingPreference,
                items: ['Non-Smoking', 'Smoking', 'Any']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) => setState(() => _smokingPreference = val),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Breakfast'),
                    value: _breakfastIncluded,
                    onChanged: (val) =>
                        setState(() => _breakfastIncluded = val),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_breakfastIncluded)
                    AppTextField(
                      controller: _breakfastPriceController,
                      label: 'Qiimaha Quraacda (Breakfast Price) *',
                      hint: '15.00',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Airport Pickup'),
                    value: _airportPickup,
                    onChanged: (val) => setState(() => _airportPickup = val),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_airportPickup)
                    AppTextField(
                      controller: _airportPickupPriceController,
                      label:
                          'Qiimaha Kasoo Qaadista Gegada (Airport Pickup Fee) *',
                      hint: '25.00',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Column(
          children: [
            SwitchListTile(
              title: const Text('Extra Bed Available'),
              subtitle: const Text(
                'Can provide an extra bed for additional cost',
              ),
              value: _extraBedAvailable,
              onChanged: (val) => setState(() => _extraBedAvailable = val),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            if (_extraBedAvailable)
              AppTextField(
                controller: _extraBedPriceController,
                label: 'Qiimaha Sariirta Dheeraadka ah (Extra Bed Price) *',
                hint: '20.00',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                prefixIcon: const Icon(Icons.attach_money),
              ),
          ],
        ),

        const SizedBox(height: 16),
        const Text('Amenities', style: TextStyle(fontWeight: FontWeight.bold)),
        ref
            .watch(amenitiesHotelProvider)
            .when(
              data: (items) => Wrap(
                spacing: 8,
                runSpacing: 0,
                children: items.map((item) {
                  final amenity = item.label;
                  final isAdded = _hotelAmenities.contains(amenity);
                  return FilterChip(
                    label: Text(amenity),
                    selected: isAdded,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _hotelAmenities.add(amenity);
                        } else {
                          _hotelAmenities.remove(amenity);
                        }
                      });
                    },
                    selectedColor: AppColors.primary.withAlpha(50),
                    checkmarkColor: AppColors.primary,
                  );
                }).toList(),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => const Text('Error loading amenities'),
            ),
        const SizedBox(height: 24),
        _buildCustomOptionsSection(),
      ],
    );
  }

  Widget _buildCustomOptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dookhyada Dheeraadka ah (Custom Options)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        const Text(
          'Halkan ku dar dookhyada kale ee qolka yeelan karo iyo qiimahooda dheeraadka ah.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        ..._customRoomOptions.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[50],
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Magaca (Title)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: option['title'],
                        decoration: InputDecoration(
                          hintText: 'e.g. Sea View',
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (v) =>
                            _customRoomOptions[index]['title'] = v,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Qiimaha (\$)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextFormField(
                        initialValue: option['price']?.toString(),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '20',
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onChanged: (v) => _customRoomOptions[index]['price'] =
                            double.tryParse(v) ?? 0.0,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () =>
                      setState(() => _customRoomOptions.removeAt(index)),
                ),
              ],
            ),
          );
        }),
        TextButton.icon(
          onPressed: () {
            setState(() {
              _customRoomOptions.add({
                'id': 'opt_${DateTime.now().millisecondsSinceEpoch}',
                'title': '',
                'price': 0.0,
              });
            });
          },
          icon: const Icon(Icons.add),
          label: const Text('Add Custom Option'),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildApartmentFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Apartment Details'),
        const SizedBox(height: 16),
        AppDropdown<String>(
          label: 'Apartment Type *',
          value: _apartmentType,
          items: [
            'Studio',
            '1BHK',
            '2BHK',
            '3BHK',
          ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (val) => setState(() => _apartmentType = val),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _aptBedroomsController,
                label: 'Bedrooms *',
                hint: 'e.g. 2',
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.bed_outlined),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AppTextField(
                controller: _aptBathroomsController,
                label: 'Bathrooms *',
                hint: 'e.g. 1',
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.bathtub_outlined),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _aptMaxGuestsController,
                label: 'Max Guests *',
                hint: 'e.g. 4',
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.group_outlined),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AppTextField(
                controller: _floorNumberController,
                label: 'Floor Number',
                hint: 'e.g. 3',
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _aptRoomsController,
          label: 'Total Rooms',
          hint: 'e.g. 4',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                title: const Text('Furnished'),
                value: _aptFurnished,
                onChanged: (val) => setState(() => _aptFurnished = val),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              child: SwitchListTile(
                title: const Text('Elevator'),
                value: _hasElevator,
                onChanged: (val) => setState(() => _hasElevator = val),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: SwitchListTile(
                title: const Text('Parking'),
                value: _hasParking,
                onChanged: (val) => setState(() => _hasParking = val),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              child: SwitchListTile(
                title: const Text('Cleaning'),
                value: _cleaningAvailable,
                onChanged: (val) => setState(() => _cleaningAvailable = val),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _houseRulesController,
          label: 'House Rules',
          hint: 'Any specific house rules...',
          maxLines: 3,
        ),
        const SizedBox(height: 24),
        const Text(
          'Optional Prices',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _cleaningPriceController,
                label: 'Lacagta Nadaafadda (Cleaning Fee)',
                hint: '0.00',
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.cleaning_services),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Amenities', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ref
            .watch(amenitiesApartmentProvider)
            .when(
              data: (items) => Wrap(
                spacing: 8,
                runSpacing: 0,
                children: items.map((item) {
                  final amenity = item.label;
                  final isAdded = _aptAmenities.contains(amenity);
                  return FilterChip(
                    label: Text(amenity),
                    selected: isAdded,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _aptAmenities.add(amenity);
                        } else {
                          _aptAmenities.remove(amenity);
                        }
                      });
                    },
                    selectedColor: AppColors.primary.withAlpha(50),
                    checkmarkColor: AppColors.primary,
                  );
                }).toList(),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => const Text('Error loading amenities'),
            ),
      ],
    );
  }

  Widget _buildTourFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Tour Pricing'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _adultPriceController,
                label: 'Qiimaha Dadka Waaweyn (Adult Price) *',
                hint: '0.00',
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.person_outline),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  if (double.tryParse(val) == null) return 'Invalid price';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AppTextField(
                controller: _childPriceController,
                label: 'Qiimaha Carruurta (Child Price) *',
                hint: '0.00',
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.child_care_outlined),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  if (double.tryParse(val) == null) return 'Invalid price';
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Extra Service Prices (Custom Package)'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _guidePriceController,
                label: 'Qiimaha Tilmaamaha (Guide Price)',
                hint: '0.00',
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.person_pin_outlined),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AppTextField(
                controller: _privateTransportPriceController,
                label: 'Qiimaha Gaadiidka Gaarka ah (Private Transport)',
                hint: '0.00',
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.directions_car_outlined),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _photographerPriceController,
                label: 'Qiimaha Sawir-qaadaha (Photographer)',
                hint: '0.00',
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.camera_alt_outlined),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AppTextField(
                controller: _vipAccessPriceController,
                label: 'Qiimaha VIP-da (VIP Access)',
                hint: '0.00',
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.stars_outlined),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _translatorPriceController,
          label: 'Qiimaha Turjumaanka (Translator Price)',
          hint: '0.00',
          keyboardType: TextInputType.number,
          prefixIcon: const Icon(Icons.translate_outlined),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('General Tour Details'),
        const SizedBox(height: 16),
        const Text(
          'Select Tour Package Type *',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _buildPackageSelector(),
        const SizedBox(height: 32),

        // 1. Shared Fields (Duration, Max Travelers & Meeting Point)
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _durationController,
                label: 'Tour Duration *',
                hint: 'e.g. 1 Day, 4 Hours',
                prefixIcon: const Icon(Icons.timer_outlined),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AppTextField(
                controller: _maxTravelersController,
                label: 'Max Travelers *',
                hint: 'e.g. 10',
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.groups_outlined),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  if (int.tryParse(val) == null) return 'Invalid number';
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _meetingPointController,
          label: 'Meeting Point / Departure *',
          hint: 'Enter the starting location',
          prefixIcon: const Icon(Icons.meeting_room),
          validator: (val) => val == null || val.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 32),

        // 2. Specific Package Fields
        if (_selectedTourPackage == TourPackage.jumma)
          _buildJummaPackageFields(),
        if (_selectedTourPackage == TourPackage.eid) _buildEidPackageFields(),
        if (_selectedTourPackage == TourPackage.custom) ...[
          _buildCustomPackageFields(),
          const SizedBox(height: 32),

          // 3. Extended Tour Fields (Only for Custom / Detailed Tours)
          _buildSectionTitle('What\'s Included?'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                [
                  'Guide',
                  'Transport',
                  'Meals',
                  'Tickets',
                  'Equipment',
                  'Insurance',
                  'Hotel Pickup',
                  'WiFi',
                ].map((item) {
                  final isSelected = _tourIncludes.contains(item);
                  return FilterChip(
                    label: Text(item),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _tourIncludes.add(item);
                        } else {
                          _tourIncludes.remove(item);
                        }
                      });
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primary,
                  );
                }).toList(),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _tourInclusionsController,
            label: 'Other Inclusions',
            hint: 'Enter any additional inclusions...',
            maxLines: 2,
            prefixIcon: const Icon(
              Icons.add_circle_outline,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('What\'s Not Included?'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                [
                  'Tips',
                  'Personal Expenses',
                  'Flights',
                  'Entry Fees',
                  'Dinner',
                  'Alcohol',
                ].map((item) {
                  final isSelected = _tourExcludes.contains(item);
                  return FilterChip(
                    label: Text(item),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _tourExcludes.add(item);
                        } else {
                          _tourExcludes.remove(item);
                        }
                      });
                    },
                    selectedColor: Colors.red.withValues(alpha: 0.1),
                    checkmarkColor: Colors.red,
                  );
                }).toList(),
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _tourExclusionsController,
            label: 'Other Exclusions',
            hint: 'Enter any additional exclusions...',
            maxLines: 2,
            prefixIcon: const Icon(
              Icons.remove_circle_outline,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Tour Itinerary'),
          const SizedBox(height: 8),
          AppTextField(
            controller: _tourItineraryController,
            label: 'Step-by-step Plan',
            hint: '08:00 AM - Pickup\n09:30 AM - Arrive at Jazeera\n...',
            maxLines: 6,
            prefixIcon: const Icon(Icons.map_outlined),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Important Information'),
          const SizedBox(height: 8),
          AppTextField(
            controller: _tourImportantInfoController,
            label: 'Requirements & Bring-alongs',
            hint: 'Must bring Swimwear, Sunsreen, ID Card',
            maxLines: 3,
            prefixIcon: const Icon(Icons.info_outline),
          ),
          const SizedBox(height: 24),
          const Text(
            'Tour Difficulty',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _tourDifficulty,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.speed_outlined),
            ),
            items: ['Easy', 'Moderate', 'Challenging', 'Strenuous'].map((diff) {
              return DropdownMenuItem(value: diff, child: Text(diff));
            }).toList(),
            onChanged: (val) => setState(() => _tourDifficulty = val!),
          ),
          const SizedBox(height: 24),
          const Text(
            'Languages Available',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ref
              .watch(languagesProvider)
              .when(
                data: (items) => Wrap(
                  spacing: 8,
                  children: items.map((item) {
                    final lang = item.label;
                    final isSelected = _tourLanguages.contains(lang);
                    return FilterChip(
                      label: Text(lang),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _tourLanguages.add(lang);
                          } else {
                            _tourLanguages.remove(lang);
                          }
                        });
                      },
                      selectedColor: AppColors.primary.withAlpha(50),
                      checkmarkColor: AppColors.primary,
                    );
                  }).toList(),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => const Text('Error loading languages'),
              ),
        ],
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Description'),
        const SizedBox(height: 16),
        AppTextField(
          controller: _descriptionController,
          label: 'Service Description *',
          hint: 'Detailed description of what you offer...',
          maxLines: 5,
          validator: (val) {
            if (val == null || val.isEmpty) {
              return 'Description is required';
            }
            if (val.length < 30) {
              return 'Must be at least 30 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Service Images'),
                const Text(
                  'Add up to 20 high-quality images.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            if (_images.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  setState(() => _images.clear());
                },
                icon: const Icon(
                  Icons.delete_sweep_outlined,
                  color: Colors.red,
                  size: 18,
                ),
                label: const Text(
                  'Clear All',
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _buildImageGrid(),
      ],
    );
  }

  Widget _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Status'),
        const SizedBox(height: 16),
        AppDropdown<ServiceStatus>(
          label: 'Availability Status',
          value: _status,
          items: [
            DropdownMenuItem(
              value: ServiceStatus.draft,
              child: _buildStatusChip(ServiceStatus.draft),
            ),
            DropdownMenuItem(
              value: ServiceStatus.active,
              child: _buildStatusChip(ServiceStatus.active),
            ),
            DropdownMenuItem(
              value: ServiceStatus.inactive,
              child: _buildStatusChip(ServiceStatus.inactive),
            ),
          ],
          onChanged: (val) => setState(() => _status = val!),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final isEditing = widget.serviceId != null;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              if (await _onWillPop() && context.mounted) {
                context.pop();
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _saveService,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isUploading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      isEditing ? 'Update Service' : 'Create Service',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const Divider(),
      ],
    );
  }

  Widget _buildStatusChip(ServiceStatus status) {
    Color color;
    switch (status) {
      case ServiceStatus.active:
        color = Colors.green;
        break;
      case ServiceStatus.inactive:
        color = Colors.grey;
        break;
      case ServiceStatus.draft:
        color = Colors.orange;
        break;
      default:
        color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:
            4, // 4 columns for a cleaner look when many images are added
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1,
      ),
      itemCount: _images.length + (_images.length < 20 ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _images.length) {
          // Stylish Add button
          return InkWell(
            onTap: _pickImage,
            hoverColor: AppColors.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.primary.withAlpha(100),
                  style: BorderStyle.solid,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(20),
                color: AppColors.primary.withAlpha(10),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_rounded,
                      color: AppColors.primary,
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Add Image',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final item = _images[index];
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: item is String
                    ? AppNetworkImage(
                        imageUrl: item,
                        fit: BoxFit.cover,
                        memCacheWidth: 300, // Reasonable size for grid preview
                      )
                    : item is Map && item.containsKey('bytes')
                    ? Image.memory(
                        item['bytes'] as Uint8List,
                        fit: BoxFit.cover,
                      )
                    : !kIsWeb && item is XFile
                    ? Image.file(io.File(item.path), fit: BoxFit.cover)
                    : const Center(child: CircularProgressIndicator()),
              ),

              // Gradient Overlay for visibility
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withAlpha(50),
                        Colors.transparent,
                        Colors.black.withAlpha(50),
                      ],
                    ),
                  ),
                ),
              ),

              // Primary Tag
              if (index == 0)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Primary',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Delete Button
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.white.withAlpha(200),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      setState(() {
                        _images.removeAt(index);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ),
              ),

              if (_isUploading &&
                  (item is XFile || (item is Map && item.containsKey('file'))))
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPackageSelector() {
    return AppDropdown<TourPackage>(
      label: 'Tour Package Type',
      value: _selectedTourPackage,
      items: TourPackage.values.map((package) {
        String label =
            package.name[0].toUpperCase() + package.name.substring(1);
        IconData icon = Icons.explore_outlined;
        Color color = AppColors.primary;

        switch (package) {
          case TourPackage.jumma:
            icon = Icons.mosque_outlined;
            color = Colors.green;
            label = 'Jumma Package';
            break;
          case TourPackage.eid:
            icon = Icons.celebration_outlined;
            color = Colors.orange;
            label = 'Eid Package';
            break;
          case TourPackage.custom:
            icon = Icons.edit_note_outlined;
            color = AppColors.primary;
            label = 'Custom / Manual Plan';
            break;
        }

        return DropdownMenuItem(
          value: package,
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(label),
            ],
          ),
        );
      }).toList(),
      onChanged: (val) => setState(() => _selectedTourPackage = val!),
    );
  }

  Widget _buildJummaPackageFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Jumma Details'),
        const SizedBox(height: 16),
        AppTextField(
          controller: _preferredLocationController,
          label: 'Preferred Location *',
          hint: 'e.g. Mogadishu, Jazeera',
          prefixIcon: const Icon(Icons.location_on_outlined),
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _jummaTransportController,
          label: 'Transport Option *',
          hint: 'e.g. Bus, Car',
          prefixIcon: const Icon(Icons.directions_bus_outlined),
        ),
        const SizedBox(height: 16),
        AppDropdown<String>(
          label: 'Accommodation *',
          value: _accommodationType,
          items: [
            'Hotel',
            'Apartment',
            'None',
          ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (val) => setState(() => _accommodationType = val!),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Include Lunch'),
          value: _includeLunch,
          onChanged: (val) => setState(() => _includeLunch = val),
          dense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  Widget _buildEidPackageFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Eid Details'),
        const SizedBox(height: 16),
        AppDropdown<String>(
          label: 'Eid Type *',
          value: _eidType,
          items: [
            'Eid al-Fitr',
            'Eid al-Adha',
          ].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (val) => setState(() => _eidType = val!),
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _eidDestinationController,
          label: 'Destination *',
          hint: 'e.g. Istanbul, Dubai',
          prefixIcon: const Icon(Icons.map_outlined),
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _eidDaysController,
          label: 'Number of Days *',
          hint: 'e.g. 7',
          keyboardType: TextInputType.number,
          prefixIcon: const Icon(Icons.timer_outlined),
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _eidTransportController,
          label: 'Transport *',
          hint: 'e.g. Flight, VIP Bus',
          prefixIcon: const Icon(Icons.flight_takeoff_outlined),
        ),
        const SizedBox(height: 16),
        AppDropdown<int>(
          label: 'Hotel Rating *',
          value: _hotelRating,
          items: [3, 4, 5]
              .map((r) => DropdownMenuItem(value: r, child: Text('$r Stars')))
              .toList(),
          onChanged: (val) => setState(() => _hotelRating = val!),
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _eidFoodController,
          label: 'Food Package *',
          hint: 'e.g. Full board, Half board',
          prefixIcon: const Icon(Icons.restaurant_menu),
        ),
      ],
    );
  }

  Widget _buildCustomPackageFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Custom Package Details'),
        const SizedBox(height: 16),
        AppTextField(
          controller: _budgetRangeController,
          label: 'Suggested Budget Range *',
          hint: 'e.g. \$500 - \$1000',
          prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
        ),
        const SizedBox(height: 24),
        const Text(
          'Available Services for Custom Plan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ref
            .watch(lookupServicesProvider)
            .when(
              data: (items) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items.map((item) {
                  final isSelected = _availableServices.contains(item.label);
                  return FilterChip(
                    label: Text(item.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _availableServices.add(item.label);
                        } else {
                          _availableServices.remove(item.label);
                        }
                      });
                    },
                    selectedColor: AppColors.primary.withAlpha(50),
                    checkmarkColor: AppColors.primary,
                  );
                }).toList(),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => const Text('Error loading services'),
            ),
      ],
    );
  }
}

class CategoryCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.name,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 100,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.grey.withAlpha(50),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primary.withAlpha(50)
                  : Colors.black.withAlpha(10),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  size: 32,
                  color: isSelected ? Colors.white : AppColors.primary,
                ),
                if (isSelected)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: AppColors.primary,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isSelected ? Colors.white : AppColors.dark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData getLookupIcon(String? iconName) {
  if (iconName == null) return Icons.help_outline;
  switch (iconName.toLowerCase()) {
    case 'hotel':
      return Icons.hotel;
    case 'apartment':
      return Icons.apartment;
    case 'explore':
    case 'tour':
      return Icons.explore;
    case 'directions_car':
    case 'transport':
      return Icons.directions_car;
    default:
      return Icons.category;
  }
}
