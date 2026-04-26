class HouseData {
  String name;
  String location;
  int rooms;
  int bathrooms;
  String? size;
  double pricePerNight;
  bool isAvailable;
  String description;
  List<String> images;

  HouseData({
    this.name = '',
    this.location = '',
    this.rooms = 0,
    this.bathrooms = 0,
    this.size,
    this.pricePerNight = 0.0,
    this.isAvailable = true,
    this.description = '',
    this.images = const [],
  });
}

class HotelData {
  String name;
  String location;
  double rating;
  int totalRooms;
  String roomTypes;
  double priceStartingFrom;
  List<String> amenities;
  String description;
  List<String> images;

  HotelData({
    this.name = '',
    this.location = '',
    this.rating = 0.0,
    this.totalRooms = 0,
    this.roomTypes = '',
    this.priceStartingFrom = 0.0,
    this.amenities = const [],
    this.description = '',
    this.images = const [],
  });
}

class ApartmentData {
  String name;
  String location;
  int floorNumber;
  int rooms;
  bool isFurnished;
  double price;
  String description;
  List<String> images;

  ApartmentData({
    this.name = '',
    this.location = '',
    this.floorNumber = 0,
    this.rooms = 0,
    this.isFurnished = false,
    this.price = 0.0,
    this.description = '',
    this.images = const [],
  });
}
