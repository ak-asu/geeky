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
