/// Car makes and their common models, used to populate the driver signup
/// dropdowns. This is a curated reference list — not exhaustive — weighted
/// toward vehicles commonly seen in Ghana. 'Other' is always the last
/// option in both the make list and every model list, so a driver whose
/// car isn't covered here can still type it in freely (see
/// signup_screen.dart's handling of the 'Other' selection).
class CarData {
  CarData._();

  static const String otherOption = 'Other (type your own)';

  static const Map<String, List<String>> makesAndModels = {
    'Toyota': [
      'Corolla', 'Camry', 'Yaris', 'Vitz', 'Avensis', 'Corona', 'Hilux',
      'Land Cruiser', 'Land Cruiser Prado', 'RAV4', 'Highlander', 'Fortuner',
      'Hiace', 'Noah', 'Sienta', 'Probox', 'Voxy',
    ],
    'Hyundai': [
      'Elantra', 'Accent', 'Sonata', 'Tucson', 'Santa Fe', 'i10', 'i20',
      'i30', 'Matrix', 'Getz', 'Grand i10', 'Creta', 'Starex',
    ],
    'Kia': [
      'Rio', 'Picanto', 'Cerato', 'Optima', 'Sportage', 'Sorento',
      'Soul', 'Carnival', 'K3',
    ],
    'Nissan': [
      'Almera', 'Sunny', 'Sentra', 'Note', 'Micra', 'Altima', 'Maxima',
      'Navara', 'Hardbody', 'X-Trail', 'Pathfinder', 'Patrol', 'Urvan',
    ],
    'Honda': [
      'Civic', 'Accord', 'City', 'Jazz', 'CR-V', 'Pilot', 'Odyssey',
    ],
    'Mercedes-Benz': [
      'C-Class', 'E-Class', 'S-Class', 'A-Class', 'GLE', 'GLC',
      'Sprinter', 'Vito', 'Viano',
    ],
    'Mazda': [
      'Mazda 2', 'Mazda 3', 'Mazda 6', 'Demio', 'CX-5', 'BT-50',
    ],
    'Mitsubishi': [
      'Lancer', 'Colt', 'Pajero', 'Outlander', 'L200', 'Canter',
    ],
    'Ford': [
      'Focus', 'Fiesta', 'Escort', 'Explorer', 'Ranger', 'Everest', 'Transit',
    ],
    'Chevrolet': [
      'Aveo', 'Cruze', 'Optra', 'Captiva', 'Trailblazer',
    ],
    'Peugeot': [
      '206', '207', '301', '307', '308', '406', '407', '508', 'Partner',
    ],
    'Suzuki': [
      'Swift', 'Alto', 'Baleno', 'Vitara', 'Jimny', 'APV',
    ],
    'Volkswagen': [
      'Golf', 'Jetta', 'Passat', 'Polo', 'Tiguan', 'Touareg',
    ],
    'BMW': [
      '3 Series', '5 Series', '7 Series', 'X3', 'X5',
    ],
    'Isuzu': [
      'D-Max', 'Trooper', 'KB', 'NPR',
    ],
    'Daewoo': [
      'Matiz', 'Lanos', 'Nubira', 'Espero',
    ],
    'Renault': [
      'Logan', 'Sandero', 'Duster', 'Clio', 'Megane',
    ],
    'Subaru': [
      'Impreza', 'Legacy', 'Forester', 'Outback',
    ],
  };

  static List<String> get makes => [...makesAndModels.keys, otherOption];

  /// Models for [make], with 'Other' always appended so a driver can type
  /// a model that isn't in this list. Returns just ['Other (type your
  /// own)'] for a make not in [makesAndModels] (i.e. the user already
  /// typed a custom make).
  static List<String> modelsFor(String? make) {
    final models = makesAndModels[make];
    return [...?models, otherOption];
  }
}
