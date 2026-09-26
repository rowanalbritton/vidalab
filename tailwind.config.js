/** @type {import('tailwindcss').Config} */
module.exports = {
    darkMode: ["class"],
    content: ["./index.html", "./src/**/*.{ts,tsx,js,jsx}"],
  theme: {
  	extend: {
  		opacity: Object.fromEntries(Array.from({ length: 101 }, (_, i) => [i, `${i / 100}`])),
  		borderRadius: {
  			lg: 'var(--radius)',
  			md: 'calc(var(--radius) - 2px)',
  			sm: 'calc(var(--radius) - 4px)'
  		},
  		colors: {
  			background: 'hsl(var(--background))',
  			foreground: 'hsl(var(--foreground))',
  			card: {
  				DEFAULT: 'hsl(var(--card))',
  				foreground: 'hsl(var(--card-foreground))'
  			},
  			popover: {
  				DEFAULT: 'hsl(var(--popover))',
  				foreground: 'hsl(var(--popover-foreground))'
  			},
  			primary: {
  				DEFAULT: 'hsl(var(--primary))',
  				foreground: 'hsl(var(--primary-foreground))'
  			},
  			secondary: {
  				DEFAULT: 'hsl(var(--secondary))',
  				foreground: 'hsl(var(--secondary-foreground))'
  			},
  			muted: {
  				DEFAULT: 'hsl(var(--muted))',
  				foreground: 'hsl(var(--muted-foreground))'
  			},
  			accent: {
  				DEFAULT: 'hsl(var(--accent))',
  				foreground: 'hsl(var(--accent-foreground))'
  			},
  			destructive: {
  				DEFAULT: 'hsl(var(--destructive))',
  				foreground: 'hsl(var(--destructive-foreground))'
  			},
  			border: 'hsl(var(--border))',
  			input: 'hsl(var(--input))',
  			ring: 'hsl(var(--ring))',
  			vida: {
  				cream: '#F9F8F5',
  				forest: '#2E463E',
  				moss: '#3c6b4f',
  				sage: '#a3b3a3',
  				sky: '#BDE0E9',
  				'sky-deep': '#87C0E4',
  				taupe: '#756a59',
  				ink: '#2E463E',
  				soft: '#5a655e',
  				line: '#E8E5DF',
  				paper: '#FFFFFF',
  				clay: '#a8412b',
  				blush: '#e8d5cf'
  			},
  			chart: {
  				'1': '#2E463E',
  				'2': '#BDE0E9',
  				'3': '#3c6b4f',
  				'4': '#a3b3a3',
  				'5': '#87C0E4'
  			},
  			sidebar: {
  				DEFAULT: 'hsl(var(--background))',
  				foreground: 'hsl(var(--foreground))',
  				primary: 'hsl(var(--primary))',
  				'primary-foreground': 'hsl(var(--primary-foreground))',
  				accent: 'hsl(var(--accent))',
  				'accent-foreground': 'hsl(var(--accent-foreground))',
  				border: 'hsl(var(--border))',
  				ring: 'hsl(var(--ring))'
  			}
  		},
  		fontFamily: {
  			heading: ['Newsreader', 'Georgia', 'serif'],
  			body: ['DM Sans', 'sans-serif'],
  			display: ['Newsreader', 'Georgia', 'serif'],
  			mono: ['var(--font-mono)']
  		},
  		keyframes: {
  			'accordion-down': { from: { height: '0' }, to: { height: 'var(--radix-accordion-content-height)' } },
  			'accordion-up': { from: { height: 'var(--radix-accordion-content-height)' }, to: { height: '0' } },
  			'fade-in': { from: { opacity: '0', transform: 'translateY(8px)' }, to: { opacity: '1', transform: 'translateY(0)' } }
  		},
  		animation: {
  			'accordion-down': 'accordion-down 0.2s ease-out',
  			'accordion-up': 'accordion-up 0.2s ease-out',
  			'fade-in': 'fade-in 0.5s ease-out'
  		}
  	}
  },
  plugins: [require("tailwindcss-animate")],
}
