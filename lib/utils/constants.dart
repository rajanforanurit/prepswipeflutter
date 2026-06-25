class AppConstants {
  AppConstants._();

  static const String baseUrl =
      'https://prepswipe-backend-fbe2athsg2hjh0e7.southeastasia-01.azurewebsites.net';

  static const List<String> examTypes = [
    'UPSC',
    'UPPCS',
    'BPSC',
    'MPPCS',
    'RAS',
    'UKPCS',
    'CGPCS',
    'JPSC',
    'HPSC',
    'WBPCS',
    'OPSC',
    'KPSC',
    'TNPSC',
    'SSC CGL',
    'SSC CHSL',
    'SSC MTS',
    'SSC CPO',
    'IBPS PO',
    'IBPS CLERK',
    'SBI PO',
    'SBI CLERK',
    'RBI GRADE B',
    'RRB NTPC',
    'RRB GROUP D',
    'RRB ALP',
    'NDA',
    'CDS',
    'AFCAT',
    'CAPF',
    'OTHER',
  ];

  static String collectionForExam(String exam) {
    switch (exam.toUpperCase()) {
      case 'UPSC':
      case 'UPPCS':
      case 'BPSC':
      case 'MPPCS':
      case 'RAS':
      case 'UKPCS':
      case 'CGPCS':
      case 'JPSC':
      case 'HPSC':
      case 'WBPCS':
      case 'OPSC':
      case 'KPSC':
      case 'TNPSC':
        return 'pcsquestions';

      case 'SSC CGL':
      case 'SSC CHSL':
      case 'SSC MTS':
      case 'SSC CPO':
      case 'IBPS PO':
      case 'IBPS CLERK':
      case 'SBI PO':
      case 'SBI CLERK':
      case 'RBI GRADE B':
      case 'RRB NTPC':
      case 'RRB GROUP D':
      case 'RRB ALP':
        return 'bookquestions';

      case 'NDA':
      case 'CDS':
      case 'AFCAT':
      case 'CAPF':
        return 'pcsquestions';

      default:
        return 'pcsquestions';
    }
  }
}
