// ===== HomiX Main JavaScript =====

// === Navbar Scroll Effect ===
const navbar = document.getElementById('navbar');
window.addEventListener('scroll', () => {
  if (window.scrollY > 50) {
    navbar.classList.add('scrolled');
  } else {
    navbar.classList.remove('scrolled');
  }
});

// === Mobile Menu Toggle ===
const menuToggle = document.getElementById('menuToggle');
const navLinks = document.getElementById('navLinks');

if (menuToggle) {
  menuToggle.addEventListener('click', () => {
    menuToggle.classList.toggle('active');
    navLinks.classList.toggle('active');
  });

  // Close menu on link click
  navLinks.querySelectorAll('a').forEach(link => {
    link.addEventListener('click', () => {
      menuToggle.classList.remove('active');
      navLinks.classList.remove('active');
    });
  });
}

// === Scroll Animations ===
const observerOptions = {
  threshold: 0.1,
  rootMargin: '0px 0px -50px 0px'
};

const observer = new IntersectionObserver((entries) => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      entry.target.classList.add('visible');
      // Add stagger delay for grid children
      const parent = entry.target.parentElement;
      if (parent) {
        const siblings = parent.querySelectorAll('.animate-on-scroll');
        siblings.forEach((sibling, index) => {
          sibling.style.transitionDelay = `${index * 0.1}s`;
        });
      }
    }
  });
}, observerOptions);

document.querySelectorAll('.animate-on-scroll').forEach(el => {
  observer.observe(el);
});

// === Video Modal ===
const videoModal = document.getElementById('videoModal');
const videoModalTitle = document.getElementById('videoModalTitle');
const videoModalBody = document.getElementById('videoModalBody');

// Video file mapping - add your video files here
const videoFiles = {
  'intro': 'videos/intro.mp4',
  'remote-door': 'videos/remote-door.mp4',
  'guest-code': 'videos/guest-code.mp4',
  'ai-camera': 'videos/ai-camera.mp4',
  'earthquake': 'videos/earthquake.mp4',
  'wall-tamper': 'videos/wall-tamper.mp4',
  'motion': 'videos/motion.mp4',
  'live-stream': 'videos/live-stream.mp4',
  'containment': 'videos/containment.mp4',
  'alerts': 'videos/alerts.mp4'
};

function openVideoModal(title, videoId) {
  videoModalTitle.textContent = title;
  
  const videoSrc = videoFiles[videoId];
  
  // Check if video file exists (try to load it)
  if (videoSrc) {
    videoModalBody.innerHTML = `
      <video controls autoplay id="modalVideo" style="width:100%;height:100%;object-fit:contain;background:#000;">
        <source src="${videoSrc}" type="video/mp4">
        <source src="${videoSrc.replace('.mp4', '.webm')}" type="video/webm">
      </video>
    `;
    
    // If video fails to load, show placeholder
    const video = document.getElementById('modalVideo');
    video.onerror = function() {
      showVideoPlaceholder(title, videoId);
    };
  } else {
    showVideoPlaceholder(title, videoId);
  }
  
  videoModal.classList.add('active');
  document.body.style.overflow = 'hidden';
}

function showVideoPlaceholder(title, videoId) {
  videoModalBody.innerHTML = `
    <div class="video-placeholder-modal">
      <div class="placeholder-icon">🎬</div>
      <p style="font-size: 1.1rem; margin-bottom: 8px;">${title}</p>
      <p style="color: var(--text-gray); font-size: 0.9rem;">فيديو 3D سيتم إضافته قريبًا</p>
      <p class="hint" style="margin-top: 12px;">أضف الفيديو في: videos/${videoId}.mp4</p>
    </div>
  `;
}

function closeVideoModal() {
  videoModal.classList.remove('active');
  document.body.style.overflow = '';
  
  // Stop video
  const video = videoModalBody.querySelector('video');
  if (video) {
    video.pause();
    video.src = '';
  }
  videoModalBody.innerHTML = '';
}

// Close modal on Escape key
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    closeVideoModal();
    const chatWidget = document.getElementById('chatWidget');
    if (chatWidget && chatWidget.classList.contains('active')) {
      toggleChat();
    }
  }
});

// === Gallery Filter (Showcase Page) ===
const filterBtns = document.querySelectorAll('.filter-btn');
const galleryCards = document.querySelectorAll('.gallery-card');

filterBtns.forEach(btn => {
  btn.addEventListener('click', () => {
    // Update active state
    filterBtns.forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    
    const filter = btn.dataset.filter;
    
    galleryCards.forEach(card => {
      if (filter === 'all' || card.dataset.category === filter) {
        card.style.display = '';
        card.style.animation = 'fadeInUp 0.4s ease forwards';
      } else {
        card.style.display = 'none';
      }
    });
  });
});

// === Contact Form ===
async function handleFormSubmit(event) {
  event.preventDefault();

  const form = document.getElementById('contactForm');
  const submitBtn = form ? form.querySelector('button[type="submit"]') : null;
  const formData = new FormData(form);
  const data = {};
  formData.forEach((value, key) => data[key] = typeof value === 'string' ? value.trim() : value);

  if (submitBtn) {
    submitBtn.disabled = true;
    submitBtn.textContent = '⏳ جاري الإرسال...';
  }

  try {
    const response = await fetch('/api/public/orders', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    });

    const result = await response.json();
    if (!response.ok || !result.success) {
      throw new Error(result.message || 'تعذر إرسال الطلب');
    }

    form.style.display = 'none';
    document.getElementById('formSuccess').classList.add('show');
  } catch (error) {
    alert(error.message || 'حدث خطأ أثناء إرسال الطلب. حاول مرة أخرى.');
  } finally {
    if (submitBtn) {
      submitBtn.disabled = false;
      submitBtn.textContent = '📋 اطلب Demo مجاني';
    }
  }
}

function resetForm() {
  const form = document.getElementById('contactForm');
  if (form) {
    form.reset();
    form.style.display = '';
    document.getElementById('formSuccess').classList.remove('show');
  }
}

// === Smooth Scroll ===
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
  anchor.addEventListener('click', function (e) {
    const href = this.getAttribute('href');
    if (href !== '#') {
      e.preventDefault();
      const target = document.querySelector(href);
      if (target) {
        target.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    }
  });
});

// === Counter Animation ===
function animateCounters() {
  const counters = document.querySelectorAll('.stat-number');
  counters.forEach(counter => {
    const target = counter.textContent;
    // Only animate pure numbers
    if (/^\d+$/.test(target)) {
      const num = parseInt(target);
      let current = 0;
      const increment = num / 50;
      const timer = setInterval(() => {
        current += increment;
        if (current >= num) {
          counter.textContent = target;
          clearInterval(timer);
        } else {
          counter.textContent = Math.floor(current);
        }
      }, 30);
    }
  });
}

// Trigger counter animation when visible
const statsRow = document.querySelector('.stats-row');
if (statsRow) {
  const statsObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        animateCounters();
        statsObserver.unobserve(entry.target);
      }
    });
  }, { threshold: 0.5 });
  
  statsObserver.observe(statsRow);
}
