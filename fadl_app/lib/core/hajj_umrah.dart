/// Step-by-step guide to Umrah and Hajj (tamattu'), limited to what the
/// schools agree on; every supplication names its source. Disputed details
/// are left to the pilgrim's guide or a scholar, as the screen says.
library;

import 'package:shared_preferences/shared_preferences.dart';

class RiteDua {
  const RiteDua(this.text, this.source);
  final String text;
  final String source;
}

/// A repeated act counted with a tap counter (tawaf, sa'i, a jamra).
class RiteCounter {
  const RiteCounter({required this.total, required this.unit, this.hint});
  final int total;

  /// "شوط" or "حصاة".
  final String unit;

  /// Optional guidance for the 1-based round, e.g. the sa'i direction.
  final String Function(int round)? hint;
}

class RiteStep {
  const RiteStep({
    required this.id,
    required this.title,
    required this.when,
    required this.details,
    this.duas = const [],
    this.counters = const [],
  });

  /// Stable id used to remember progress.
  final String id;
  final String title;

  /// Time or place of the step, shown under its title.
  final String when;
  final List<String> details;
  final List<RiteDua> duas;

  /// Labelled counters; a step may need several (the three jamarat).
  final List<(String, RiteCounter)> counters;
}

class RiteGuide {
  const RiteGuide(this.id, this.title, this.steps);
  final String id;
  final String title;
  final List<RiteStep> steps;
}

const _talbiya = RiteDua(
  'لَبَّيْكَ اللَّهُمَّ لَبَّيْكَ، لَبَّيْكَ لَا شَرِيكَ لَكَ لَبَّيْكَ، إِنَّ الْحَمْدَ وَالنِّعْمَةَ لَكَ وَالْمُلْكَ، لَا شَرِيكَ لَكَ',
  'البخاري ١٥٤٩، مسلم ١١٨٤',
);

const _betweenCorners = RiteDua(
  'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
  'بين الركن اليماني والحجر الأسود — أبو داود ١٨٩٢، وحسّنه الألباني',
);

const _enterMosque = RiteDua(
  'اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ',
  'عند دخول المسجد بالرجل اليمنى — مسلم ٧١٣',
);

const _safaMarwa = [
  RiteDua(
    'إِنَّ الصَّفَا وَالْمَرْوَةَ مِنْ شَعَائِرِ اللَّهِ',
    'يقرؤها عند أول صعوده الصفا ويقول: أبدأ بما بدأ الله به — مسلم ١٢١٨',
  ),
  RiteDua(
    'اللَّهُ أَكْبَرُ، اللَّهُ أَكْبَرُ، اللَّهُ أَكْبَرُ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ، أَنْجَزَ وَعْدَهُ، وَنَصَرَ عَبْدَهُ، وَهَزَمَ الْأَحْزَابَ وَحْدَهُ',
    'على الصفا والمروة مستقبلًا القبلة، ثلاث مرات يدعو بينها — مسلم ١٢١٨',
  ),
];

String _tawafHint(int round) => round <= 3
    ? 'يبدأ من الحجر الأسود مكبّرًا. الرَّمَل (الإسراع بخطًا متقاربة) في الأشواط الثلاثة الأولى للرجال في طواف القدوم والعمرة.'
    : 'يمشي مشيًا معتادًا، ويكبّر كلما حاذى الحجر الأسود.';

String _saiHint(int round) => round.isOdd
    ? 'من الصفا إلى المروة، ويسرع الرجل بين العلمين الأخضرين.'
    : 'من المروة إلى الصفا، ويسرع الرجل بين العلمين الأخضرين.';

const _tawaf = RiteCounter(total: 7, unit: 'شوط', hint: _tawafHint);
const _sai = RiteCounter(total: 7, unit: 'شوط', hint: _saiHint);
const _pebbles = RiteCounter(total: 7, unit: 'حصاة');

const _tawafStep = RiteStep(
  id: 'tawaf',
  title: 'الطواف',
  when: 'المسجد الحرام',
  details: [
    'يكون على طهارة، ويجعل الكعبة عن يساره.',
    'يبدأ كل شوط من الحجر الأسود: يستلمه أو يشير إليه ويكبّر، ولا يزاحم.',
    'الاضطباع للرجل في طواف القدوم والعمرة: يجعل وسط الرداء تحت إبطه الأيمن وطرفيه على عاتقه الأيسر.',
    'سبعة أشواط كاملة، وليس لكل شوط دعاء مخصوص؛ يذكر الله ويدعو بما شاء ويقرأ القرآن.',
  ],
  duas: [
    RiteDua(
      'اللَّهُ أَكْبَرُ',
      'كلما أتى الحجر الأسود أشار إليه وكبّر — البخاري ١٦١٣',
    ),
    _betweenCorners,
  ],
  counters: [('أشواط الطواف', _tawaf)],
);

const _prayerAndZamzam = RiteStep(
  id: 'two_rakahs',
  title: 'ركعتا الطواف وزمزم',
  when: 'خلف مقام إبراهيم إن تيسّر، وإلا ففي أي مكان من المسجد',
  details: [
    'يغطي كتفه الأيمن بعد الطواف، ثم يصلي ركعتين.',
    'يقرأ في الأولى بعد الفاتحة «قل يا أيها الكافرون» وفي الثانية «قل هو الله أحد».',
    'يشرب من ماء زمزم ويدعو بما شاء.',
  ],
  duas: [
    RiteDua(
      'وَاتَّخِذُوا مِنْ مَقَامِ إِبْرَاهِيمَ مُصَلًّى',
      'البقرة ١٢٥، وقرأها النبي ﷺ حين تقدّم إلى المقام — مسلم ١٢١٨',
    ),
    RiteDua(
      'مَاءُ زَمْزَمَ لِمَا شُرِبَ لَهُ',
      'ابن ماجه ٣٠٦٢، وصححه الألباني',
    ),
  ],
);

const _saiStep = RiteStep(
  id: 'sai',
  title: 'السعي بين الصفا والمروة',
  when: 'المسعى',
  details: [
    'يبدأ بالصفا وينتهي بالمروة: الذهاب شوط والرجوع شوط، فالمجموع سبعة.',
    'يصعد الصفا ويستقبل القبلة ويرفع يديه للدعاء، ويفعل على المروة مثل ذلك.',
    'لا تشترط الطهارة للسعي، لكنها أفضل.',
  ],
  duas: _safaMarwa,
  counters: [('أشواط السعي', _sai)],
);

const umrahGuide = RiteGuide('umrah', 'العمرة', [
  RiteStep(
    id: 'ihram',
    title: 'الإحرام من الميقات',
    when: 'عند الميقات أو محاذاته، ومن كان دونه فمن مكانه',
    details: [
      'يغتسل ويتطيّب في بدنه لا في ثياب الإحرام، ويلبس الرجل إزارًا ورداءً أبيضين، وتلبس المرأة ما شاءت من الثياب الساترة دون نقاب أو قفازين.',
      'ينوي الدخول في النسك قائلًا: «لبيك عمرة».',
      'من خاف عائقًا يمنعه من الإتمام اشترط: «فإن حبسني حابس فمحلّي حيث حبستني».',
      'يكثر من التلبية حتى يبدأ الطواف، ويرفع الرجل بها صوته وتخفضه المرأة.',
    ],
    duas: [
      _talbiya,
      RiteDua(
        'فَإِنْ حَبَسَنِي حَابِسٌ فَمَحِلِّي حَيْثُ حَبَسْتَنِي',
        'الاشتراط لمن خاف عائقًا — البخاري ٥٠٨٩، مسلم ١٢٠٧',
      ),
    ],
  ),
  RiteStep(
    id: 'prohibitions',
    title: 'محظورات الإحرام',
    when: 'من الإحرام حتى التحلل',
    details: [
      'إزالة الشعر وتقليم الأظفار، والطيب في البدن أو الثوب.',
      'للرجل: لبس المخيط على هيئة البدن وتغطية الرأس. للمرأة: النقاب والقفازان.',
      'عقد النكاح، والجماع ومقدماته، وقتل صيد البر.',
      'من وقع في شيء منها ناسيًا أو جاهلًا أو مضطرًا فليسأل أهل العلم عمّا يلزمه، ففي ذلك تفصيل.',
    ],
  ),
  RiteStep(
    id: 'enter',
    title: 'دخول المسجد الحرام',
    when: 'عند الوصول إلى مكة',
    details: [
      'يقطع التلبية عند بدء الطواف.',
      'يقدّم رجله اليمنى ويقول دعاء دخول المسجد.',
    ],
    duas: [_enterMosque],
  ),
  _tawafStep,
  _prayerAndZamzam,
  _saiStep,
  RiteStep(
    id: 'halq',
    title: 'الحلق أو التقصير',
    when: 'بعد السعي',
    details: [
      'يحلق الرجل رأسه، وهو أفضل، أو يقصّر من جميعه.',
      'تقصّر المرأة من أطراف شعرها قدر أنملة.',
      'وبذلك تمت العمرة وحلّ له كل ما حرم بالإحرام.',
    ],
    duas: [
      RiteDua(
        'اللَّهُمَّ ارْحَمِ الْمُحَلِّقِينَ ... وَالْمُقَصِّرِينَ',
        'دعا النبي ﷺ للمحلّقين ثلاثًا ثم للمقصّرين — البخاري ١٧٢٧، مسلم ١٣٠١',
      ),
    ],
  ),
]);

const hajjGuide = RiteGuide('hajj', 'الحج (التمتع)', [
  RiteStep(
    id: 'umrah_first',
    title: 'أداء العمرة أولًا',
    when: 'في أشهر الحج قبل يوم التروية',
    details: [
      'المتمتع يحرم بالعمرة من الميقات ويؤديها كاملة (انظر دليل العمرة)، ثم يتحلل ويبقى في مكة حلالًا.',
      'القارن والمفرد يبقيان على إحرامهما، ولهما أحكام خاصة يُرجع فيها لمرشد الحملة.',
    ],
  ),
  RiteStep(
    id: 'tarwiyah',
    title: 'يوم التروية: الإحرام بالحج والتوجه إلى منى',
    when: '٨ ذي الحجة',
    details: [
      'يحرم بالحج من مكانه في مكة ضحى، قائلًا: «لبيك حجًا».',
      'يتوجه إلى منى فيصلي بها الظهر والعصر والمغرب والعشاء والفجر، يقصر الرباعية ولا يجمع.',
    ],
    duas: [_talbiya],
  ),
  RiteStep(
    id: 'arafah',
    title: 'يوم عرفة: الوقوف بعرفة',
    when: '٩ ذي الحجة — ركن الحج الأعظم',
    details: [
      'يسير إلى عرفة بعد طلوع الشمس، ويصلي الظهر والعصر جمع تقديم قصرًا.',
      'يتأكد أنه داخل حدود عرفة، ويتفرغ للذكر والدعاء مستقبلًا القبلة رافعًا يديه.',
      'يبقى حتى غروب الشمس، فالوقوف إليه واجب.',
    ],
    duas: [
      RiteDua(
        'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ، وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
        'خير الدعاء دعاء يوم عرفة — الترمذي ٣٥٨٥، وحسّنه الألباني',
      ),
      RiteDua('الْحَجُّ عَرَفَةُ', 'الترمذي ٨٨٩، وصححه الألباني'),
    ],
  ),
  RiteStep(
    id: 'muzdalifah',
    title: 'المبيت بمزدلفة',
    when: 'ليلة ١٠ ذي الحجة',
    details: [
      'يدفع من عرفة بعد الغروب بسكينة، ويصلي بمزدلفة المغرب والعشاء جمعًا مع قصر العشاء.',
      'يبيت بها ويصلي الفجر، ثم يذكر الله ويدعو مستقبلًا القبلة حتى يُسفر جدًا.',
      'يجوز للضعفة والنساء ومن معهم الدفع بعد منتصف الليل.',
      'يلتقط حصى الرمي من حيث تيسّر، وهي صغيرة كحصى الخذف.',
    ],
    duas: [
      RiteDua(
        'فَإِذَا أَفَضْتُمْ مِنْ عَرَفَاتٍ فَاذْكُرُوا اللَّهَ عِنْدَ الْمَشْعَرِ الْحَرَامِ',
        'البقرة ١٩٨',
      ),
    ],
  ),
  RiteStep(
    id: 'nahr',
    title: 'يوم النحر',
    when: '١٠ ذي الحجة — يوم العيد',
    details: [
      'يرمي جمرة العقبة بسبع حصيات متعاقبات يكبّر مع كل حصاة، ويقطع التلبية مع أول حصاة.',
      'يذبح هديه (على المتمتع والقارن).',
      'يحلق أو يقصّر، فيتحلل التحلل الأول ويحلّ له كل شيء إلا النساء.',
      'يطوف طواف الإفاضة ويسعى سعي الحج، فيتحلل التحلل الثاني.',
      'الترتيب سنة، ومن قدّم بعضها على بعض فلا حرج.',
    ],
    duas: [
      RiteDua('اللَّهُ أَكْبَرُ', 'مع كل حصاة — البخاري ١٧٥١'),
      RiteDua(
        'افْعَلْ وَلَا حَرَجَ',
        'جواب النبي ﷺ لمن قدّم أو أخّر يوم النحر — البخاري ٨٣، مسلم ١٣٠٦',
      ),
    ],
    counters: [('رمي جمرة العقبة', _pebbles)],
  ),
  RiteStep(
    id: 'tawaf_ifadah',
    title: 'طواف الإفاضة وسعي الحج',
    when: 'يوم النحر أو بعده',
    details: [
      'طواف الإفاضة ركن، وكيفيته كطواف العمرة بلا رمل ولا اضطباع.',
      'ثم يسعى المتمتع بين الصفا والمروة سبعة أشواط.',
    ],
    counters: [('أشواط الطواف', _tawaf), ('أشواط السعي', _sai)],
  ),
  RiteStep(
    id: 'tashreeq',
    title: 'أيام التشريق: المبيت بمنى ورمي الجمرات',
    when: '١١ و١٢ ذي الحجة، و١٣ لمن تأخر',
    details: [
      'يبيت بمنى أكثر الليل.',
      'يرمي كل يوم بعد الزوال الجمرات الثلاث، كل جمرة بسبع حصيات يكبّر مع كل حصاة.',
      'يبدأ بالصغرى ويقف بعدها يدعو طويلًا، ثم الوسطى ويقف بعدها يدعو، ثم العقبة ولا يقف بعدها.',
      'من تعجّل خرج من منى يوم ١٢ قبل غروب الشمس، ومن تأخر بات ليلة ١٣ ورمى يومها.',
    ],
    duas: [
      RiteDua(
        'اللَّهُ أَكْبَرُ',
        'مع كل حصاة، والوقوف للدعاء بعد الصغرى والوسطى — البخاري ١٧٥١–١٧٥٣',
      ),
    ],
    counters: [
      ('الجمرة الصغرى', _pebbles),
      ('الجمرة الوسطى', _pebbles),
      ('جمرة العقبة', _pebbles),
    ],
  ),
  RiteStep(
    id: 'farewell',
    title: 'طواف الوداع',
    when: 'آخر عهده بمكة عند السفر',
    details: [
      'يطوف سبعة أشواط بلا سعي، ويكون آخر ما يفعله بمكة.',
      'يسقط عن الحائض والنفساء.',
    ],
    duas: [
      RiteDua(
        'أُمِرَ النَّاسُ أَنْ يَكُونَ آخِرُ عَهْدِهِمْ بِالْبَيْتِ، إِلَّا أَنَّهُ خُفِّفَ عَنِ الْحَائِضِ',
        'البخاري ١٧٥٥، مسلم ١٣٢٨',
      ),
    ],
    counters: [('أشواط الطواف', _tawaf)],
  ),
]);

const riteGuides = [umrahGuide, hajjGuide];

/// Where the pilgrim stopped: the current step and each counter's tally,
/// kept on the device so a closed app resumes in the middle of tawaf.
class RiteProgress {
  RiteProgress(this.preferences, this.guide);
  final SharedPreferences preferences;
  final RiteGuide guide;

  String get _stepKey => 'fadl.rites.${guide.id}.step';
  String _counterKey(String step, int index) =>
      'fadl.rites.${guide.id}.$step.$index';

  int get step =>
      (preferences.getInt(_stepKey) ?? 0).clamp(0, guide.steps.length - 1);

  bool get started => preferences.containsKey(_stepKey);

  Future<void> setStep(int value) =>
      preferences.setInt(_stepKey, value.clamp(0, guide.steps.length - 1));

  int count(RiteStep step, int index) =>
      preferences.getInt(_counterKey(step.id, index)) ?? 0;

  /// Adds [delta] within 0…total and returns the new tally.
  Future<int> add(RiteStep step, int index, int delta) async {
    final total = step.counters[index].$2.total;
    final value = (count(step, index) + delta).clamp(0, total);
    await preferences.setInt(_counterKey(step.id, index), value);
    return value;
  }

  Future<void> reset(RiteStep step, int index) =>
      preferences.remove(_counterKey(step.id, index));

  /// Forgets the step and every counter, to perform the rites again.
  Future<void> restart() async {
    await preferences.remove(_stepKey);
    for (final step in guide.steps) {
      for (var i = 0; i < step.counters.length; i++) {
        await preferences.remove(_counterKey(step.id, i));
      }
    }
  }
}
