// Saari settings ek jagah: API key, models, aur aap ki default profile.

// Key code mein nahi rakhte. Website ke upar chaabi (key) icon se paste karein.
const String apiKey = String.fromEnvironment('GEMINI_KEY');

// Aap ki default profile. My Profile mein edit karne par browser wali version use hogi.
const String defaultName = 'Muhammad Muneeb Javed';
const String defaultProfile = r'''
Degree & University: Final-year Bachelor of Science in Information Technology (BSIT) student at the University of Sargodha, Pakistan.

Target Degree & Field: Master's degree (MS) in Artificial Intelligence, Software Engineering, or Computer Science via the CSC Scholarship for Fall 2027 and other international scholarships.

Technical Skills: Python (FastAPI), MERN Stack (MongoDB, Express.js, React.js, Node.js), C++, Docker, AWS EC2, CrewAI, ChromaDB (RAG), Cloud Deployment, full-stack web development.

Flagship Project & Research:
Project Name: CRAFT (Code Review and Feedback Tutoring System / Multi-Agent AI System).
Architecture: A distributed, service-oriented multi-agent framework using CrewAI, Google Gemini API, and ChromaDB for domain-specific RAG. It features an Adaptive Personalization Engine and a secure Docker Sandbox execution environment to prevent AI hallucination and protect cloud infrastructure.
Live Demo / Hosting: Deployed on AWS EC2 at http://16.170.238.234
Working Paper: Authored an academic preprint titled "CRAFT: An Adaptive Multi-Agent AI Tutoring System with RAG and Sandboxed Execution for C++ Education."

Contact & Links:
Email: muneeb0705@gmail.com
Phone / WhatsApp: +92 303 9538698
''';

// Pehla model fail/busy ho to agla try hoga
const List<String> geminiModels = [
  'gemini-3.5-flash',
  'gemini-3.5-flash-lite',
];
// Sirf in emails ko app ke andar jane denge
const List<String> allowedEmails = [
  'mj8016124@gmail.com' ,
  'muneebjaved0705@gmail.com'


];