const revealElements = document.querySelectorAll('.reveal');

const observer = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add('visible');
        observer.unobserve(entry.target);
      }
    });
  },
  { threshold: 0.15 },
);

revealElements.forEach((element) => observer.observe(element));

const counters = document.querySelectorAll('[data-counter]');
let countersAnimated = false;

function animateCounters() {
  if (countersAnimated) {
    return;
  }
  countersAnimated = true;

  for (const counter of counters) {
    const target = Number(counter.dataset.counter);
    const step = Math.max(1, Math.floor(target / 25));
    let value = 0;
    const timer = setInterval(() => {
      value += step;
      if (value >= target) {
        counter.textContent = `${target}+`;
        clearInterval(timer);
        return;
      }
      counter.textContent = `${value}+`;
    }, 35);
  }
}

const statsSection = document.querySelector('.stats');

if (statsSection) {
  const counterObserver = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          animateCounters();
          counterObserver.disconnect();
          break;
        }
      }
    },
    { threshold: 0.4 },
  );

  counterObserver.observe(statsSection);
}

const carousel = document.querySelector('[data-carousel]');

if (carousel) {
  const track = carousel.querySelector('.carousel-track');
  const slides = Array.from(carousel.querySelectorAll('.carousel-slide'));
  const dotsRoot = document.querySelector('[data-dots]');
  const nextBtn = carousel.querySelector('[data-next]');
  const prevBtn = carousel.querySelector('[data-prev]');

  let index = 0;
  let autoRotateTimer;

  function setSlide(nextIndex) {
    index = (nextIndex + slides.length) % slides.length;
    track.style.transform = `translateX(-${index * 100}%)`;

    const dots = dotsRoot?.querySelectorAll('.carousel-dot') ?? [];
    dots.forEach((dot, dotIndex) => {
      dot.classList.toggle('active', dotIndex === index);
      dot.setAttribute('aria-selected', dotIndex === index ? 'true' : 'false');
    });

    const counter = carousel.querySelector('.slide-counter');
    if (counter) {
      counter.textContent = index + 1;
    }
  }

  function stopAutoRotate() {
    if (autoRotateTimer) {
      clearInterval(autoRotateTimer);
    }
  }

  function startAutoRotate() {
    stopAutoRotate();
    autoRotateTimer = setInterval(() => {
      setSlide(index + 1);
    }, 6500);
  }

  if (dotsRoot) {
    slides.forEach((_, dotIndex) => {
      const dot = document.createElement('button');
      dot.type = 'button';
      dot.className = 'carousel-dot';
      dot.setAttribute('aria-label', `Go to diagram ${dotIndex + 1}`);
      dot.setAttribute('role', 'tab');
      dot.addEventListener('click', () => {
        setSlide(dotIndex);
        startAutoRotate();
      });
      dotsRoot.appendChild(dot);
    });
  }

  prevBtn?.addEventListener('click', () => {
    setSlide(index - 1);
    startAutoRotate();
  });

  nextBtn?.addEventListener('click', () => {
    setSlide(index + 1);
    startAutoRotate();
  });

  carousel.addEventListener('mouseenter', stopAutoRotate);
  carousel.addEventListener('mouseleave', startAutoRotate);
  carousel.addEventListener('keydown', (event) => {
    if (event.key === 'ArrowRight') {
      setSlide(index + 1);
      startAutoRotate();
    }
    if (event.key === 'ArrowLeft') {
      setSlide(index - 1);
      startAutoRotate();
    }
  });

  setSlide(0);
  startAutoRotate();
}

const flipCards = document.querySelectorAll('.flip-card');

for (const card of flipCards) {
  card.addEventListener('click', () => {
    card.classList.toggle('is-flipped');
  });

  card.addEventListener('keydown', (event) => {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      card.classList.toggle('is-flipped');
    }
  });
}
