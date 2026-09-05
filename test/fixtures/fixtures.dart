/// 실제 lms.kumoh.ac.kr:82 응답에서 뽑은 형태. 토큰 값은 익명화했다.
const loginSuccessJson = {
  'code': '200',
  'message': 'Success',
  'data': {
    'accessToken': 'header.accessPayload.sig',
    'refreshToken': 'header.refreshPayload.sig',
  },
};

const userProfileJson = {
  'code': '200',
  'message': 'Success',
  'data': {
    'id': null,
    'canvasId': 59580,
    'name': '홍길동',
    'birth': '20000110',
    'mobile': '',
    'email': 'student@example.com',
    'loginId': '20250000',
    'division': '컴퓨터공학부',
    'subDivision': '인공지능공학전공',
    'agreementFlag': false,
    'createdAt': '2026-09-04 23:58:42',
    'profileUrl': 'https://canvas.kumoh.ac.kr/images/messages/avatar-50.png',
    'role': 'STUDENT',
    'locale': 'ko',
  },
};

const accountsJson = {
  'code': '200',
  'message': 'Success',
  'data': {
    'id': 1,
    'parentAccountId': null,
    'name': 'KIT',
    'workflowState': 'active',
    'universityName': '국립금오공과',
    'logoUrl': '',
    'scaleGpa': 4.5,
    'themeColor': '#00A9CE',
    'canvasType': 'OPEN_SOURCE',
    'ssoType': null,
  },
};

const termsJson = {
  'code': '200',
  'message': 'Success',
  'data': [
    {
      'id': 8,
      'name': '2026-2학기',
      'startAt': '2026-09-01T00:01:00',
      'endAt': '2026-12-22T00:00:59',
      'workflowState': 'active',
    },
    {
      'id': 6,
      'name': '2026-1학기',
      'startAt': '2026-03-03T00:01:00',
      'endAt': '2026-06-25T00:00:00',
      'workflowState': 'active',
    },
  ],
};

const coursesJson = {
  'code': '200',
  'message': 'Success',
  'data': {
    'courses': [
      {
        'no': null,
        'id': 4831,
        'name': '리눅스시스템프로그래밍-01',
        'startAt': null,
        'endAt': null,
        'courseCode': '리눅스시스템프로그래밍-GA2015-01',
        'totalStudents': 28,
        'sisCourseId': '2026-2-12211-GA2015-01',
        'teachers': [
          {
            'id': 83520,
            'loginId': 'F00357',
            'displayName': '[컴퓨터공학부] 윤현주',
            'avatarImageUrl': 'https://canvas.kumoh.ac.kr/images/messages/avatar-50.png',
          }
        ],
        'enrollments': [
          {'type': 'student', 'role': 'StudentEnrollment', 'enrollment_state': 'active'}
        ],
        'colorCode': null,
        'publicDescription': null,
        'institution': '인공지능공학전공',
        'courseProgress': {
          'error': {'message': 'no progress available because this course is not module based'}
        },
        'enrollmentTermId': 8,
        'imageDownloadUrl': null,
        'workflowState': 'available',
        'courseFormat': 'ONLINE',
      },
      {
        'id': 5682,
        'name': '모두를위한아두이노-02',
        'courseCode': '모두를위한아두이노-LA0424-02',
        'totalStudents': 40,
        'teachers': [
          {'id': 83648, 'loginId': 'F00489', 'displayName': '[산업.빅데이터공학부] 신승혁', 'avatarImageUrl': null}
        ],
        'enrollments': [
          {'type': 'student', 'role': 'StudentEnrollment', 'enrollment_state': 'active'}
        ],
        'colorCode': null,
        'institution': '교양학부',
        'enrollmentTermId': 8,
        'workflowState': 'available',
        'courseFormat': 'ONLINE',
      },
    ],
  },
};

const calendarEventsJson = {
  'code': '200',
  'message': 'Success',
  'data': {
    'calendarEvents': [
      {
        'id': 'assignment_7931',
        'title': '[토의 과제] 리눅스 상식',
        'start_at': '2026-09-02T14:59:00Z',
        'end_at': '2026-09-02T14:59:00Z',
        'workflow_state': 'published',
        'description': '<p>1. 리눅스 상식을 다룬 질문들에 대해 토의하고 답을 합의한다.</p>',
        'context_code': 'course_4831',
        'context_name': '리눅스시스템프로그래밍-01',
        'hidden': null,
        'html_url': 'https://canvas.kumoh.ac.kr/courses/4831/assignments/7931',
        'all_day': true,
      },
    ],
  },
};

const announcementsJson = {
  'code': '200',
  'message': 'Success',
  'data': {
    'announcements': [
      {
        'id': 991,
        'title': '2주차 실습 안내',
        'message': '<p>실습실은 D동 401호입니다.</p>',
        'postedAt': '2026-09-03T01:00:00Z',
        'contextCode': 'course_4831',
        'contextName': '리눅스시스템프로그래밍-01',
        'htmlUrl': 'https://canvas.kumoh.ac.kr/courses/4831/discussion_topics/991',
        'userName': '윤현주',
      },
    ],
  },
};

const emptyAnnouncementsJson = {
  'code': '200',
  'message': 'Success',
  'data': {'announcements': <Map<String, dynamic>>[]},
};

const springAuthErrorJson = {
  'timestamp': '2026-09-04T15:25:53.939+00:00',
  'status': 401,
  'error': 'Unauthorized',
  'path': '/api/v1/user/profile',
};
