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
